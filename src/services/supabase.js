import { createClient } from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL;const key=import.meta.env.VITE_SUPABASE_ANON_KEY;if(!url||!key)throw new Error('ไม่พบ Supabase configuration กรุณาตรวจสอบไฟล์ .env');
export const supabase=createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
export async function publicRpc(name,args={}){const {data,error}=await supabase.rpc(name,args);if(error)throw error;return data}
export async function rpc(name,args={}){const {data:{session},error:sessionError}=await supabase.auth.getSession();if(sessionError)throw sessionError;if(!session)throw new Error('กรุณาเข้าสู่ระบบครูก่อนใช้งาน');return publicRpc(name,args)}
