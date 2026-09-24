def issues:
  if type == "object" and has("issues") then .issues else . end;

def control_state:
  {
    status,
    assignee: (.assignee // ""),
  };

# A lane claim's guarded update assigns the lane and appends a
# `lane-claim:<lane>` note marker. A lane name need not look like a host-scoped
# agent identity, so the unreleased marker is what proves the claim.
def claim_lane:
  (.notes // "") as $notes
  | ($notes | rindex("lane-claim:")) as $claim
  | ($notes | rindex("lane-release:")) as $release
  | if $claim == null or ($release != null and $release > $claim) then ""
    else ($notes[$claim + 11:] | split("\n")[0] | split(" ")[0]) end
  | if test("^[a-z][a-z0-9_-]{0,31}$") then . else "" end;

def active_machine_claim:
  .status == "in_progress"
  and (
    ((.assignee // "") | test("^[a-z][a-z0-9]*(?:[_-][a-z0-9]+)+$"))
    or (claim_lane as $lane | $lane != "" and .assignee == $lane)
  );

# Only a live machine claim outranks the tracker's workflow state, so a close
# made in the tracker stands on any Bead no machine holds. Labels take the
# tracker's value: Beads keeps no control state in them.
(issues
  | map(select(active_machine_claim) | { key: .id, value: control_state })
  | from_entries) as $desired_before_pull
| reduce (
    $journal[]
    | select(
        (.actor // "") != ""
        and .actor != $actor
        and .issue != null
        and (.op == "create" or .op == "update" or .op == "close")
      )
  ) as $event (
    $desired_before_pull;
    .[$event.issue_id] = ($event.issue | control_state)
  )
| . as $desired
| ($current[0]
  | issues
  | map({ key: .id, value: control_state })
  | from_entries) as $actual
| $desired
| to_entries[]
| .key as $id
| .value as $want
| $actual[$id] as $have
| select($have != null)
| {
    id: $id,
    desired_status: $want.status,
    desired_assignee: $want.assignee,
    current_status: $have.status,
    current_assignee: $have.assignee,
  }
| select(
    .desired_status != .current_status
    or .desired_assignee != .current_assignee
  )
