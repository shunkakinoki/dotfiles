CREATE TABLE issues (
  id VARCHAR(255) PRIMARY KEY,
  notes TEXT NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'open',
  assignee VARCHAR(255)
);
INSERT INTO issues (id, notes, status, assignee) VALUES
  ('host-claim', '', 'in_progress', 'kamino1_exec_gj70y1'),
  ('hyphen-lane', '', 'in_progress', 'dup-unifier'),
  ('null-write', '', 'in_progress', 'kamino1_exec_gj70y1'),
  ('marked-lane', 'picked up\nlane-claim:reviewer at 2026-09-24T13:00:00Z', 'in_progress', 'reviewer'),
  ('reclaimed-lane', 'lane-claim:reviewer\nlane-release:reviewer\nlane-claim:reviewer', 'in_progress', 'reviewer'),
  ('released-lane', 'lane-claim:reviewer\nlane-release:reviewer', 'in_progress', 'reviewer'),
  ('unmarked-lane', '', 'in_progress', 'reviewer'),
  ('other-lane', 'lane-claim:writer', 'in_progress', 'reviewer'),
  ('uppercase-lane', 'lane-claim:Reviewer', 'in_progress', 'Reviewer'),
  ('human', '', 'in_progress', 'alice@example.com'),
  ('unclaim', '', 'in_progress', 'kamino1_exec_gj70y1'),
  ('handoff', '', 'in_progress', 'kamino1_exec_gj70y1'),
  ('was-open', '', 'open', 'kamino1_exec_gj70y1');
