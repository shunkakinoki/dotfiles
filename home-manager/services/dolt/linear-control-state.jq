def issues:
  if type == "object" and has("issues") then .issues else . end;

# A lane claim's guarded status update appends a `lane-claim:<lane>` note
# marker, and its release appends `lane-release:<lane>`. Lanes never write the
# assignee, and the tracker pull never writes notes, so the unreleased marker
# is what proves the claim.
def claim_lane:
  (.notes // "") as $notes
  | ($notes | rindex("lane-claim:")) as $claim
  | ($notes | rindex("lane-release:")) as $release
  | if $claim == null or ($release != null and $release > $claim) then ""
    else ($notes[$claim + 11:] | split("\n")[0] | split(" ")[0]) end
  | if test("^[a-z][a-z0-9_-]{0,31}$") then . else "" end;

def active_machine_claim:
  .status == "in_progress" and claim_lane != "";

# Only a live machine claim outranks the tracker's workflow state, so a close
# made in the tracker stands on any Bead no machine holds. Assignee and labels
# take the tracker's value: Beads keeps no control state in them.
(issues
  | map(select(active_machine_claim) | { key: .id, value: .status })
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
    .[$event.issue_id] = $event.issue.status
  )
| . as $desired
| ($current[0]
  | issues
  | map({ key: .id, value: .status })
  | from_entries) as $actual
| $desired
| to_entries[]
| select($actual[.key] != null and $actual[.key] != .value)
| {
    id: .key,
    desired_status: .value,
    current_status: $actual[.key],
  }
