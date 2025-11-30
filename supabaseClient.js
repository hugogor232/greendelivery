import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'

const SUPABASE_URL = 'https://onwudtaovhgbetrxjonx.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ud3VkdGFvdmhnYmV0cnhqb254Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1MjU2MDMsImV4cCI6MjA4MDEwMTYwM30.U4x_7bf5SovLETMOINsjy8M3NPJvWvdTd_mGmJCLS_Q'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)