-- Set of manual tests for the hashtag extraction.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-02

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'asdf';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'asdf#';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'as#df';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'as #df';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'as#df ';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'as#d #f';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'as #dasd #fasdf';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;

DO
$$
DECLARE
string text ;
hashtag text;
BEGIN
string := 'Este es un ejemplo real #ONL #Colombia';
CALL staging.get_hashtag(string,hashtag);
RAISE NOTICE 'new string: "%", hashtag: "%".', string, hashtag;
END
$$
;
