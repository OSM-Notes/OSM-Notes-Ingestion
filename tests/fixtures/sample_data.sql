-- Sample data for testing
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

-- Sample notes data
INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at, id_country) VALUES
(123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'open', NULL, 1),
(456, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'closed', '2013-05-01T10:15:30Z', 1),
(789, 51.5074, -0.1278, '2013-05-01T12:30:15Z', 'open', NULL, 2),
(101, 48.8566, 2.3522, '2013-05-02T09:45:20Z', 'closed', '2013-05-03T14:20:10Z', 3);

-- Sample users data
INSERT INTO users (user_id, username) VALUES
(123, 'user1'),
(456, 'user2'),
(789, 'user3'),
(101, 'user4');

-- Sample note comments data
INSERT INTO note_comments (id, note_id, sequence_action, event, created_at, id_user) VALUES
(1, 123, 1, 'opened', '2013-04-28T02:39:27Z', 123),
(2, 456, 1, 'opened', '2013-04-30T15:20:45Z', 456),
(3, 456, 2, 'closed', '2013-05-01T10:15:30Z', 789),
(4, 789, 1, 'opened', '2013-05-01T12:30:15Z', 101),
(5, 101, 1, 'opened', '2013-05-02T09:45:20Z', 123),
(6, 101, 2, 'closed', '2013-05-03T14:20:10Z', 456);

-- Sample note comments text data
INSERT INTO note_comments_text (id, note_id, sequence_action, body) VALUES
(1, 123, 1, 'This is a test comment for note 123'),
(2, 456, 1, 'This is a test comment for note 456'),
(3, 456, 2, 'Closing note 456'),
(4, 789, 1, 'This is a test comment for note 789'),
(5, 101, 1, 'This is a test comment for note 101'),
(6, 101, 2, 'Closing note 101');

-- Sample sync tables data
INSERT INTO notes_sync (note_id, latitude, longitude, created_at, status, closed_at, id_country) VALUES
(201, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'open', NULL, 1),
(202, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'closed', '2013-05-01T10:15:30Z', 1);

INSERT INTO note_comments_sync (id, note_id, sequence_action, event, created_at, id_user, username) VALUES
(201, 201, 1, 'opened', '2013-04-28T02:39:27Z', 123, 'user1'),
(202, 202, 1, 'opened', '2013-04-30T15:20:45Z', 456, 'user2'),
(203, 202, 2, 'closed', '2013-05-01T10:15:30Z', 789, 'user3');

INSERT INTO note_comments_text_sync (id, note_id, sequence_action, body) VALUES
(201, 201, 1, 'This is a test sync comment for note 201'),
(202, 202, 1, 'This is a test sync comment for note 202'),
(203, 202, 2, 'Closing sync note 202');

-- Sample API tables data
INSERT INTO notes_api (note_id, latitude, longitude, created_at, status, closed_at) VALUES
(301, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'open', NULL),
(302, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'closed', '2013-05-01T10:15:30Z');

INSERT INTO note_comments_api (note_id, sequence_action, event, created_at, id_user, username) VALUES
(301, 1, 'opened', '2013-04-28T02:39:27Z', 123, 'user1'),
(302, 1, 'opened', '2013-04-30T15:20:45Z', 456, 'user2'),
(302, 2, 'closed', '2013-05-01T10:15:30Z', 789, 'user3');

INSERT INTO note_comments_text_api (note_id, sequence_action, body) VALUES
(301, 1, 'This is a test API comment for note 301'),
(302, 1, 'This is a test API comment for note 302'),
(302, 2, 'Closing API note 302');

-- Sample properties data
INSERT INTO properties (key, value, updated_at) VALUES
('last_planet_update', '2013-05-01T00:00:00Z', NOW()),
('last_api_update', '2013-05-02T00:00:00Z', NOW()),
('lock', 'test_lock', NOW());

-- Sample max_note_timestamp data
INSERT INTO max_note_timestamp (timestamp) VALUES
('2013-05-01T00:00:00Z'); 