def issues:
  if type == "object" and has("issues") then .issues else . end;

def control_state:
  {
    status,
    assignee: (.assignee // ""),
  };

($current[0]
  | issues
  | map({ key: .id, value: control_state })
  | from_entries) as $actual
# Beads owns custody: Linear cannot hold an agent or session assignee, so the
# pull blanks every in-progress claim it did not see change. A Bead the pull
# left in progress with no assignee keeps the one it had before the pull. The
# tracker still holds what the ledger recorded, so `kept` spares a re-push.
| ($before[0]
  | issues
  | map(
      select(.status == "in_progress" and (.assignee // "") != "")
      | select($actual[.id] == { status: "in_progress", assignee: "" })
      | { key: .id, value: (control_state + { kept: true }) }
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
