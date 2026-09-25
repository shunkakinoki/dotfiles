def issues:
  if type == "object" and has("issues") then .issues else . end;

def control_state:
  {
    status,
    assignee: (.assignee // ""),
  };

# The tracker owns workflow state, assignment, and labels, so only a mutation
# another actor made while the pull was in flight outranks what it wrote.
reduce (
    $journal[]
    | select(
        (.actor // "") != ""
        and .actor != $actor
        and .issue != null
        and (.op == "create" or .op == "update" or .op == "close")
      )
  ) as $event (
    {};
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
