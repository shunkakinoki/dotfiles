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
# pull writes either no assignee or the tracker user's email over every claim
# the tracker shows In Progress. Neither is a handoff: a claim the pull left in
# progress keeps the assignee it had before, unless the tracker moved it from
# one tracker user to another. The tracker still holds what the ledger
# recorded, so `kept` spares a re-push.
# A release the tracker never received comes back the same way, as In Progress
# under no one or the tracker user, and nothing else would release it again,
# so it is restored and re-pushed. A tracker demotion or close still stands.
| ($before[0]
  | issues
  | map(
      control_state as $was
      | $actual[.id] as $now
      | select($now != null and $now.status == "in_progress")
      | select($now.assignee == "" or ($now.assignee | contains("@")))
      | if $was.status == "in_progress" and $was.assignee != ""
          and ($now.assignee == "" or ($was.assignee | contains("@") | not))
        then { key: .id, value: ($was + { kept: true }) }
        elif $was == { status: "open", assignee: "" }
        then { key: .id, value: $was }
        else empty
        end
    )
  | from_entries) as $kept
# A survey lease is local-only, so the tracker's copy of it is stale whatever it
# says: a lease keeps the control state it had before the pull. One held in
# progress keeps it only while a pass's unexpired bd lease stood behind it at
# the snapshot: one without had no live pass, and the pull's close drops the
# bd lease, so putting it back would leave a holder that never heartbeats and
# that `bd reclaim` cannot reap. Lease writes skip the events journal, so a pass
# that took or released its lease during the pull is invisible here; `lease`
# marks the repair for the caller to check the lease's own history first.
| ($before[0]
  | issues
  | map(
      select((.title // "") | startswith("Survey lease: "))
      | select(.status != "in_progress" or (.lease_expires_at // "") > $snapshot)
      | { key: .id, value: (control_state + { kept: true }) }
    )
  | from_entries) as $leases
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
    $kept + $leases;
    .[$event.issue_id] = ($event.issue | control_state)
  )
| to_entries[]
| .key as $id
| .value as $want
| $actual[$id] as $have
| select($have != null)
# A closed Bead stays closed: a pulled close came from the tracker, and the
# journal's newer local event can be the claim that preceded it, so restoring it
# would hand delivered work back to the lane that already finished it. A lease
# close never comes from the tracker, so a pulled one is undone.
| select($have.status != "closed" or $leases[$id] != null)
| {
    id: $id,
    desired_status: $want.status,
    desired_assignee: $want.assignee,
    current_status: $have.status,
    current_assignee: $have.assignee,
    kept: ($want.kept // false),
    lease: ($leases[$id] != null),
  }
| select(
    .desired_status != .current_status
    or .desired_assignee != .current_assignee
  )
