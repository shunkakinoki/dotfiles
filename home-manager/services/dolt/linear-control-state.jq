def issues:
  if type == "object" and has("issues") then .issues else . end;

def is_control_label:
  ascii_downcase as $label
  | $label == "agent-plan"
    or $label == "agent-plan-stale"
    or $label == "awaiting-human"
    or $label == "awaiting-operator"
    or $label == "coordinator"
    or $label == "foreign"
    or $label == "hold"
    or $label == "human"
    or $label == "operator-hold"
    or $label == "planner-intake"
    or $label == "product"
    or $label == "recovery-incident"
    or $label == "reserved"
    or $label == "stall"
    or ($label | startswith("foreign/"))
    or ($label | startswith("product/"))
    or ($label | startswith("reserved/"));

def control_labels:
  reduce ((.labels // [])[] | select(is_control_label)) as $label (
    {};
    .[$label | ascii_downcase] = $label
  );

def control_state:
  {
    status,
    assignee: (.assignee // ""),
    control_labels: control_labels,
  };

def active_machine_claim:
  .status == "in_progress"
  and ((.assignee // "") | test("^[a-z][a-z0-9]*(?:[_-][a-z0-9]+)+$"));

(issues
  | map(
      select(active_machine_claim or ((control_labels | length) > 0))
      | { key: .id, value: control_state }
    )
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
    add_labels: [
      $want.control_labels
      | to_entries[]
      | select($have.control_labels[.key] == null)
      | .value
    ],
    remove_labels: [
      $have.control_labels
      | to_entries[]
      | select($want.control_labels[.key] == null)
      | .value
    ],
  }
| select(
    .desired_status != .current_status
    or .desired_assignee != .current_assignee
    or (.add_labels | length) > 0
    or (.remove_labels | length) > 0
  )
