CREATE TRIGGER beads_keep_machine_claim BEFORE UPDATE ON issues FOR EACH ROW
SET NEW.assignee = IF(
  OLD.status = 'in_progress'
  AND NEW.status = 'in_progress'
  AND COALESCE(NEW.assignee, '') = ''
  AND (
    OLD.assignee REGEXP '^[a-z][a-z0-9]*([_-][a-z0-9]+)+$'
    OR (
      OLD.assignee REGEXP '^[a-z][a-z0-9_-]{0,31}$'
      AND LOCATE('lane-claim:', OLD.notes) > 0
      AND CHAR_LENGTH(SUBSTRING_INDEX(OLD.notes, 'lane-claim:', -1))
        < CHAR_LENGTH(SUBSTRING_INDEX(OLD.notes, 'lane-release:', -1))
      AND SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(OLD.notes, 'lane-claim:', -1), '\n', 1), ' ', 1)
        = OLD.assignee
    )
  ),
  OLD.assignee,
  NEW.assignee
)
