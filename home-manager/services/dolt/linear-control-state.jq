def issues:
  if type == "object" and has("issues") then .issues else . end;

def control_state:
  {
    status,
    assignee: (.assignee // ""),
  };

# Fleet actors are host-scoped lane or session names; a tracker user is an
# email address, and Linear can hold nothing else.
def fleet_claim:
  .status == "in_progress"
  and (.assignee // "") != ""
  and ((.assignee // "") | contains("@") | not);

($current[0]
  | issues
  | map({ key: .id, value: control_state })
  | from_entries) as $actual
# Beads owns custody: Linear cannot hold a fleet assignee, so the pull blanks
# every fleet claim, stamps a person on it, or moves it back to a tracker state
# the claim has not reached yet. A Bead that was a fleet claim before the pull
# keeps that claim whatever the pull wrote. When the pull left its status alone,
# the tracker already holds that status and cannot hold the assignee, so `kept`
# spares a re-push.
| ($before[0]
  | issues
  | map(
      select(fleet_claim)
      | select($actual[.id] != null and $actual[.id] != control_state)
      | { key: .id, value: (control_state + { kept: ($actual[.id].status == .status) }) }
    )
  | from_entries) as $kept
# The tracker owns workflow state and labels, so only a mutation another actor
# made that the tracker has not yet received outranks what the pull wrote.
| reduce (
    $journal[]
    | select(
        (.actor // "") != ""
        and .actor != $actor
        and .issue != null
        and (.op == "create" or .op == "update" or .op == "close")
      )
  ) as $event (
    $kept;
    .[$event.issue_id] = ($event.issue | control_state)
  )
| to_entries[]
| .key as $id
| .value as $want
| $actual[$id] as $have
| select($have != null)
# A closed Bead stays closed: a pulled close came from the tracker, and the
# journal's newer local event can be the claim that preceded it, so restoring it
# would hand delivered work back to the lane that already finished it.
| select($have.status != "closed")
| {
    id: $id,
    desired_status: $want.status,
    desired_assignee: $want.assignee,
    current_status: $have.status,
    current_assignee: $have.assignee,
    kept: ($want.kept // false),
  }
| select(
    .desired_status != .current_status
    or .desired_assignee != .current_assignee
  )
