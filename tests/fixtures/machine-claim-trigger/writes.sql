UPDATE issues SET assignee = '' WHERE id NOT IN ('null-write', 'unclaim', 'handoff', 'was-open');
UPDATE issues SET assignee = NULL WHERE id = 'null-write';
UPDATE issues SET assignee = '', status = 'open' WHERE id = 'unclaim';
UPDATE issues SET assignee = 'kamino2_exec_ab12cd' WHERE id = 'handoff';
UPDATE issues SET assignee = '', status = 'in_progress' WHERE id = 'was-open';
