import { Pool, PoolClient } from 'pg';
export const pool = new Pool({connectionString:process.env.DATABASE_URL,max:5,ssl:process.env.DATABASE_URL?.includes('neon.tech')?{rejectUnauthorized:true}:undefined});
export type DB = Pool|PoolClient;
export async function tx<T>(fn:(db:PoolClient)=>Promise<T>):Promise<T>{const db=await pool.connect();try{await db.query('BEGIN');const result=await fn(db);await db.query('COMMIT');return result}catch(e){await db.query('ROLLBACK');throw e}finally{db.release()}}
export async function migrate(){await pool.query(`
CREATE TABLE IF NOT EXISTS rayeq_users(id uuid PRIMARY KEY,name text NOT NULL,email text UNIQUE NOT NULL,password_hash text NOT NULL,role text NOT NULL CHECK(role IN ('customer','worker_pending','worker','admin')),email_verified boolean NOT NULL DEFAULT false,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS rayeq_sessions(token_hash text PRIMARY KEY,user_id uuid NOT NULL REFERENCES rayeq_users(id),expires_at timestamptz NOT NULL);
CREATE TABLE IF NOT EXISTS rayeq_codes(email text NOT NULL,purpose text NOT NULL,code_hash text NOT NULL,expires_at timestamptz NOT NULL,last_sent_at timestamptz NOT NULL DEFAULT now(),attempts integer NOT NULL DEFAULT 0,PRIMARY KEY(email,purpose));
CREATE TABLE IF NOT EXISTS rayeq_limits(key text PRIMARY KEY,hits integer NOT NULL,expires_at timestamptz NOT NULL);
CREATE TABLE IF NOT EXISTS rayeq_profiles(user_id uuid PRIMARY KEY REFERENCES rayeq_users(id) ON DELETE CASCADE,phone text NOT NULL DEFAULT '',avatar_bytes bytea,avatar_version integer NOT NULL DEFAULT 0,updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS rayeq_settings(key text PRIMARY KEY,value jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS rayeq_services(id uuid PRIMARY KEY,name_ar text NOT NULL,description_ar text NOT NULL DEFAULT '',category text NOT NULL DEFAULT '',duration_minutes integer NOT NULL CHECK(duration_minutes BETWEEN 5 AND 480),price_minor integer NOT NULL CHECK(price_minor>=0),version integer NOT NULL DEFAULT 1,active boolean NOT NULL DEFAULT true);
ALTER TABLE rayeq_services ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE rayeq_services ADD COLUMN IF NOT EXISTS name_en text NOT NULL DEFAULT '';
ALTER TABLE rayeq_services ADD COLUMN IF NOT EXISTS description_en text NOT NULL DEFAULT '';
ALTER TABLE rayeq_services ADD COLUMN IF NOT EXISTS category_en text NOT NULL DEFAULT '';
CREATE TABLE IF NOT EXISTS rayeq_areas(id uuid PRIMARY KEY,name_ar text NOT NULL,travel_fee_minor integer NOT NULL CHECK(travel_fee_minor>=0),version integer NOT NULL DEFAULT 1,active boolean NOT NULL DEFAULT true);
ALTER TABLE rayeq_areas ADD COLUMN IF NOT EXISTS name_en text NOT NULL DEFAULT '';
CREATE TABLE IF NOT EXISTS rayeq_employees(id uuid PRIMARY KEY,user_id uuid UNIQUE REFERENCES rayeq_users(id),name text NOT NULL,phone text NOT NULL DEFAULT '',active boolean NOT NULL DEFAULT true,service_ids uuid[] NOT NULL DEFAULT '{}',area_ids uuid[] NOT NULL DEFAULT '{}',salary_minor integer NOT NULL DEFAULT 0 CHECK(salary_minor>=0),created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE rayeq_employees ADD COLUMN IF NOT EXISTS name_en text NOT NULL DEFAULT '';
ALTER TABLE rayeq_employees ADD COLUMN IF NOT EXISTS availability_status text NOT NULL DEFAULT 'offline' CHECK(availability_status IN ('offline','available','busy'));
ALTER TABLE rayeq_employees ADD COLUMN IF NOT EXISTS coarse_zone_lat numeric(5,2) CHECK(coarse_zone_lat BETWEEN -90 AND 90);
ALTER TABLE rayeq_employees ADD COLUMN IF NOT EXISTS coarse_zone_lon numeric(5,2) CHECK(coarse_zone_lon BETWEEN -180 AND 180);
ALTER TABLE rayeq_employees ADD COLUMN IF NOT EXISTS location_updated_at timestamptz;
ALTER TABLE rayeq_employees ADD COLUMN IF NOT EXISTS availability_updated_at timestamptz;
CREATE TABLE IF NOT EXISTS rayeq_bookings(id uuid PRIMARY KEY,reference text UNIQUE NOT NULL,customer_id uuid NOT NULL REFERENCES rayeq_users(id),employee_id uuid REFERENCES rayeq_employees(id),status text NOT NULL DEFAULT 'PENDING',requested_at timestamptz,start_at timestamptz,end_at timestamptz,version integer NOT NULL DEFAULT 1,document jsonb NOT NULL,internal_notes text NOT NULL DEFAULT '',created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS rayeq_customer_bookings ON rayeq_bookings(customer_id,created_at DESC,id);
CREATE INDEX IF NOT EXISTS rayeq_employee_bookings ON rayeq_bookings(employee_id,start_at,end_at);
CREATE TABLE IF NOT EXISTS rayeq_reviews(id uuid PRIMARY KEY,booking_id uuid UNIQUE NOT NULL REFERENCES rayeq_bookings(id),customer_id uuid NOT NULL REFERENCES rayeq_users(id),employee_id uuid NOT NULL REFERENCES rayeq_employees(id),rating integer NOT NULL CHECK(rating BETWEEN 1 AND 5),text text NOT NULL DEFAULT '' CHECK(char_length(text)<=1000),customer_display_name text NOT NULL,demo_seed text,hidden boolean NOT NULL DEFAULT false,moderation_reason text NOT NULL DEFAULT '',moderated_at timestamptz,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS rayeq_reviews_employee ON rayeq_reviews(employee_id,created_at DESC,id) WHERE NOT hidden;
CREATE TABLE IF NOT EXISTS rayeq_work_photos(id uuid PRIMARY KEY,employee_id uuid NOT NULL REFERENCES rayeq_employees(id),image_bytes bytea NOT NULL,byte_size integer NOT NULL CHECK(byte_size BETWEEN 1 AND 256000 AND byte_size=octet_length(image_bytes)),width integer NOT NULL CHECK(width BETWEEN 1 AND 1600),height integer NOT NULL CHECK(height BETWEEN 1 AND 1600),demo_seed text,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS rayeq_work_photos_employee ON rayeq_work_photos(employee_id,created_at DESC,id);
CREATE TABLE IF NOT EXISTS rayeq_idempotency(user_id uuid NOT NULL REFERENCES rayeq_users(id),key text NOT NULL,request_hash text NOT NULL,booking_id uuid NOT NULL REFERENCES rayeq_bookings(id),PRIMARY KEY(user_id,key));
CREATE TABLE IF NOT EXISTS rayeq_audit(id bigserial PRIMARY KEY,actor_id uuid REFERENCES rayeq_users(id),action text NOT NULL,entity_id text NOT NULL,details jsonb NOT NULL DEFAULT '{}',created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS rayeq_payroll(id uuid PRIMARY KEY,employee_id uuid NOT NULL REFERENCES rayeq_employees(id),month text NOT NULL,base_minor integer NOT NULL CHECK(base_minor>=0),bonus_minor integer NOT NULL DEFAULT 0 CHECK(bonus_minor>=0),paid boolean NOT NULL DEFAULT false,note text NOT NULL DEFAULT '',UNIQUE(employee_id,month));
INSERT INTO rayeq_settings(key,value) VALUES ('config','{"intakeEnabled":false,"isDemo":true,"support":{},"instapayInstructions":""}') ON CONFLICT DO NOTHING;
`)}
export async function audit(db:DB,actor:string,action:string,entity:string,details:unknown={}){await db.query('INSERT INTO rayeq_audit(actor_id,action,entity_id,details) VALUES($1,$2,$3,$4)',[actor,action,entity,JSON.stringify(details)])}
