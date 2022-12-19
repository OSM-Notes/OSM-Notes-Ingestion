ALTER TABLE dwh.dimension_users
 ADD CONSTRAINT pk_user_dim
 PRIMARY KEY (user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_created
 FOREIGN KEY (created_id_user)
 REFERENCES dwh.dimension_users (user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_closed
 FOREIGN KEY (closed_id_user)
 REFERENCES dwh.dimension_users (user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_action
 FOREIGN KEY (action_id_user)
 REFERENCES dwh.dimension_users (user_id);

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT pk_countries_dim
 PRIMARY KEY (country_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_country
 FOREIGN KEY (id_country)
 REFERENCES dwh.dimension_countries (country_id);

ALTER TABLE dwh.dimension_time
 ADD CONSTRAINT pk_date_dim
 PRIMARY KEY (date_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_date
 FOREIGN KEY (action_id_date)
 REFERENCES dwh.dimension_time (date_id);

