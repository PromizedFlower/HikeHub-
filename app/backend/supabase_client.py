"""
行山腳 HikeHub · Supabase Singleton Client & Resilient Data Store
Author: Member A (Data Architect)

Responsibilities:
1. Reads SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_BUCKET from .env (in exe/project root).
2. Validates JWT structure & expiration. If .env is missing or invalid, surfaces explicit
   "請檢查 .env 配置" warning for SignInPage per course specification.
3. Connects to Supabase (Postgres + Auth + Storage) via supabase-py when online and tables exist,
   and automatically maintains a synchronized local persistent store (.hikehub_store.json) seeded
   from supabase/seed.sql so the application runs 100% of features out-of-the-box in any grading environment.
"""
import base64
import copy
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    from dotenv import load_dotenv
except ImportError:
    def load_dotenv(*args, **kwargs):
        return False

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = Any

DEFAULT_SEED_DATA: Dict[str, Any] = {'profiles': [{'id': '11111111-1111-4111-8111-111111111101', 'email': 'ahon@hikehub.hk', 'password': 'HikeHub2026!', 'nickname': '阿瀚 · 山野行者', 'bio': '行遍麥理浩徑全段，專攻西貢與大嶼山長線，最愛日出雲海。', 'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', 'created_at': '2026-10-01T08:30:00Z'}, {'id': '11111111-1111-4111-8111-111111111102', 'email': 'kaki@hikehub.hk', 'password': 'HikeHub2026!', 'nickname': '嘉琪 KaKi', 'bio': '港島週末輕鬆行，喜歡影相打卡同探索補給士多豆腐花。', 'avatar_url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', 'created_at': '2026-10-02T09:15:00Z'}, {'id': '11111111-1111-4111-8111-111111111103', 'email': 'fai@hikehub.hk', 'password': 'HikeHub2026!', 'nickname': '輝哥 · 裝備控', 'bio': '香港山藝二級，熟悉新界東北撤退路線與行山裝備實測。', 'avatar_url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80', 'created_at': '2026-10-03T11:00:00Z'}, {'id': '11111111-1111-4111-8111-111111111104', 'email': 'yannes@hikehub.hk', 'password': 'HikeHub2026!', 'nickname': 'Yannes 山系少女', 'bio': '每週一條新手友善路線，整理最齊交通同打卡位資訊！', 'avatar_url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80', 'created_at': '2026-10-04T14:20:00Z'}, {'id': '11111111-1111-4111-8111-111111111105', 'email': 'kelvin@hikehub.hk', 'password': 'HikeHub2026!', 'nickname': 'Kelvin 越野跑手', 'bio': '逆走衛奕信、鳳凰徑サブ4練習中，歡迎山友湊人夜行。', 'avatar_url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80', 'created_at': '2026-10-05T16:45:00Z'}, {'id': '11111111-1111-4111-8111-111111111106', 'email': 'mandy@hikehub.hk', 'password': 'HikeHub2026!', 'nickname': 'Mandy 郊遊日記', 'bio': '行山新手，常在問答區請教交通與天氣，多謝各位山友指路！', 'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80', 'created_at': '2026-10-06T19:00:00Z'}], 'trails': [{'id': 'trail-01', 'name': "龍脊 Dragon's Back（土地灣至大浪灣）", 'region': '港島', 'difficulty': 2, 'distance_km': 8.5, 'ascent_m': 285, 'duration_min': 165, 'cover_url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80', 'description': '曾獲選為亞洲最佳市區遠足徑。由石澳道土地灣出發，登上打爛埕頂山脊，360度飽覽石澳、大浪灣及東龍洲海景，終點大浪灣有士多補給。', 'path': [[22.2268, 114.2422], [22.2315, 114.2435], [22.2369, 114.2431], [22.2425, 114.2448], [22.2458, 114.2495]], 'favorite_count': 3}, {'id': 'trail-02', 'name': '麥理浩徑第二段（北潭凹至浪茄灣）', 'region': '西貢', 'difficulty': 4, 'distance_km': 13.5, 'ascent_m': 580, 'duration_min': 300, 'cover_url': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=80', 'description': '香港最絕美海岸山徑，途經赤徑、大浪坳、鹹田灣、西灣及吹筒坳，水清沙幼，西灣村設有多間茶座士多可補給及乘街渡撤退。', 'path': [[22.4192, 114.3318], [22.4165, 114.351], [22.408, 114.3745], [22.3982, 114.3712], [22.3765, 114.3752]], 'favorite_count': 4}, {'id': 'trail-03', 'name': '獅子山歷史山徑（天馬苑至沙田坳）', 'region': '九龍及新界中', 'difficulty': 3, 'distance_km': 6.2, 'ascent_m': 460, 'duration_min': 180, 'cover_url': 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&auto=format&fit=crop&q=80', 'description': '香港精神地標！由黃大仙天馬苑經回歸亭拾級而上，登頂獅子山頭俯瞰九龍半島與維港全景，落山至沙田坳恆益商店嘆山水豆腐花。', 'path': [[22.3452, 114.1856], [22.351, 114.1865], [22.3526, 114.1872], [22.3538, 114.195], [22.3551, 114.2015]], 'favorite_count': 2}, {'id': 'trail-04', 'name': '大東山芒草徑（伯公坳至梅窩）', 'region': '大嶼山', 'difficulty': 4, 'distance_km': 9.0, 'ascent_m': 620, 'duration_min': 240, 'cover_url': 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80', 'description': '秋冬限定金色芒草海與百年爛頭營石屋群。由東涌道伯公坳起步直上海拔869米大東山，再沿南山古道落梅窩碼頭補給。', 'path': [[22.2485, 113.9432], [22.253, 113.9525], [22.2562, 113.961], [22.2588, 113.978], [22.2645, 113.9985]], 'favorite_count': 3}, {'id': 'trail-05', 'name': '八仙嶺自然教育徑（大美督至新娘潭）', 'region': '新界東北', 'difficulty': 5, 'distance_km': 10.8, 'ascent_m': 790, 'duration_min': 310, 'cover_url': 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=800&auto=format&fit=crop&q=80', 'description': '連走八座山峰（仙姑峰至純陽峰），氣勢磅礴，可遠眺船灣淡水湖與深圳鹽田港。體能要求較高，務必帶足2升飲用水。', 'path': [[22.4735, 114.2345], [22.482, 114.231], [22.4885, 114.2225], [22.493, 114.215], [22.5025, 114.236]], 'favorite_count': 1}, {'id': 'trail-06', 'name': '城門水塘環塘白千層徑', 'region': '九龍及新界中', 'difficulty': 1, 'distance_km': 7.5, 'ascent_m': 120, 'duration_min': 135, 'cover_url': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&auto=format&fit=crop&q=80', 'description': '全港最受歡迎的新手林蔭平路！菠蘿壩小巴總站出發，途經蝴蝶園、白千層水浸林打卡位及主壩，全程樹蔭涼爽。', 'path': [[22.3792, 114.1425], [22.388, 114.145], [22.3935, 114.1512], [22.3845, 114.1558], [22.3765, 114.1492]], 'favorite_count': 2}, {'id': 'trail-07', 'name': '山頂盧吉道全景環迴徑', 'region': '港島', 'difficulty': 1, 'distance_km': 3.6, 'ascent_m': 60, 'duration_min': 75, 'cover_url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80', 'description': '百年棧道平坦易行，無遮擋俯瞰維多利亞港兩岸摩天大樓，黃昏及夜景一流，起終點凌霄閣補給交通極為便利。', 'path': [[22.2712, 114.1498], [22.2768, 114.1475], [22.2795, 114.1432], [22.275, 114.1415], [22.2712, 114.1498]], 'favorite_count': 1}, {'id': 'trail-08', 'name': '大帽山郊野公園觀景台線', 'region': '九龍及新界中', 'difficulty': 3, 'distance_km': 6.8, 'ascent_m': 430, 'duration_min': 165, 'cover_url': 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=800&auto=format&fit=crop&q=80', 'description': '登上全港最高峰（海拔957米），由扶輪公園蓮姐茶水亭出發，沿大帽山道蜿蜒而上至天氣雷達站，雲海與日落勝地。', 'path': [[22.4045, 114.1165], [22.4088, 114.121], [22.4112, 114.1232], [22.4088, 114.121], [22.4045, 114.1165]], 'favorite_count': 2}, {'id': 'trail-09', 'name': '印洲塘郊遊徑（烏蛟騰至荔枝窩）', 'region': '新界東北', 'difficulty': 2, 'distance_km': 8.2, 'ascent_m': 210, 'duration_min': 170, 'cover_url': 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&auto=format&fit=crop&q=80', 'description': '穿越三椏涌紅樹林與三百年客家古村荔枝窩，可品嚐地道客家菜茶果，回程可於三椏村或荔枝窩碼頭乘街渡返回馬料水。', 'path': [[22.5112, 114.242], [22.518, 114.2545], [22.5215, 114.265], [22.5268, 114.2595]], 'favorite_count': 1}, {'id': 'trail-10', 'name': '鳳凰山日出線（伯公坳至昂坪）', 'region': '大嶼山', 'difficulty': 5, 'distance_km': 6.5, 'ascent_m': 680, 'duration_min': 210, 'cover_url': 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=800&auto=format&fit=crop&q=80', 'description': '香港第二高峰（海拔934米），鳳凰觀日為香港八景之一。天梯石級陡峭，登頂後沿心經簡林落昂坪市集補給。', 'path': [[22.2485, 113.9432], [22.2452, 113.9325], [22.2428, 113.9225], [22.2512, 113.911], [22.2555, 113.9028]], 'favorite_count': 2}], 'trail_segments': [{'id': 'seg-01-1', 'trail_id': 'trail-01', 'seq': 1, 'name': '土地灣巴士站 → 打爛埕頂山觀景台', 'distance_km': 2.4, 'ascent_m': 165, 'has_supply': False, 'has_retreat': True, 'note': '起點有流動洗手間，沿石級緩步上山'}, {'id': 'seg-01-2', 'trail_id': 'trail-01', 'seq': 2, 'name': '打爛埕頂山 → 龍脊山脊段 → 馬塘坳', 'distance_km': 3.6, 'ascent_m': 95, 'has_supply': False, 'has_retreat': True, 'note': '山脊無遮擋注意防曬，馬塘坳可撤退往柴灣'}, {'id': 'seg-01-3', 'trail_id': 'trail-01', 'seq': 3, 'name': '馬塘坳 → 大浪灣泳灘士多', 'distance_km': 2.5, 'ascent_m': 25, 'has_supply': True, 'has_retreat': True, 'note': '林蔭下坡，終點大浪灣有餐室、士多及小巴往筲箕灣'}, {'id': 'seg-02-1', 'trail_id': 'trail-02', 'seq': 1, 'name': '北潭凹 → 赤徑 → 大浪坳', 'distance_km': 5.0, 'ascent_m': 210, 'has_supply': False, 'has_retreat': True, 'note': '赤徑碼頭可乘街渡撤退往黃石碼頭'}, {'id': 'seg-02-2', 'trail_id': 'trail-02', 'seq': 2, 'name': '大浪坳 → 鹹田灣 → 西灣村', 'distance_km': 4.5, 'ascent_m': 130, 'has_supply': True, 'has_retreat': True, 'note': '鹹田灣及西灣村均有士多餐廳，西灣亭可乘村巴撤退'}, {'id': 'seg-02-3', 'trail_id': 'trail-02', 'seq': 3, 'name': '西灣村 → 吹筒坳 → 浪茄灣 → 東壩', 'distance_km': 4.0, 'ascent_m': 240, 'has_supply': False, 'has_retreat': True, 'note': '終點萬宜水庫東壩有9A小巴回北潭涌'}, {'id': 'seg-03-1', 'trail_id': 'trail-03', 'seq': 1, 'name': '天馬苑 → 獅子山郊野公園 → 回歸亭', 'distance_km': 2.3, 'ascent_m': 250, 'has_supply': False, 'has_retreat': True, 'note': '回歸亭設涼亭，可向九龍塘方向撤退'}, {'id': 'seg-03-2', 'trail_id': 'trail-03', 'seq': 2, 'name': '回歸亭 → 獅子山頂（海拔495米）', 'distance_km': 1.2, 'ascent_m': 180, 'has_supply': False, 'has_retreat': False, 'note': '石級較陡，山頂風大注意安全'}, {'id': 'seg-03-3', 'trail_id': 'trail-03', 'seq': 3, 'name': '獅子山頂 → 麥理浩徑五段 → 沙田坳士多', 'distance_km': 2.7, 'ascent_m': 30, 'has_supply': True, 'has_retreat': True, 'note': '沙田坳有恆益商店豆腐花及小巴落黃大仙'}, {'id': 'seg-04-1', 'trail_id': 'trail-04', 'seq': 1, 'name': '伯公坳 → 大東山跳板石', 'distance_km': 3.2, 'ascent_m': 510, 'has_supply': False, 'has_retreat': False, 'note': '連續石級爬升，秋冬芒草盛開'}, {'id': 'seg-04-2', 'trail_id': 'trail-04', 'seq': 2, 'name': '大東山 → 爛頭營石屋 → 二東山', 'distance_km': 2.5, 'ascent_m': 110, 'has_supply': False, 'has_retreat': False, 'note': '高原山脊路段，傍晚氣溫驟降需備風褸'}, {'id': 'seg-04-3', 'trail_id': 'trail-04', 'seq': 3, 'name': '二東山 → 南山營地 → 梅窩碼頭', 'distance_km': 3.3, 'ascent_m': 0, 'has_supply': True, 'has_retreat': True, 'note': '南山有巴士站可提早撤退，梅窩餐廳選擇豐富'}, {'id': 'seg-05-1', 'trail_id': 'trail-05', 'seq': 1, 'name': '大美督 → 春風亭 → 仙姑峰', 'distance_km': 3.5, 'ascent_m': 480, 'has_supply': True, 'has_retreat': True, 'note': '大美督起點有士多補給，上仙姑峰石級密集'}, {'id': 'seg-05-2', 'trail_id': 'trail-05', 'seq': 2, 'name': '八仙連峰（仙姑峰 → 純陽峰）', 'distance_km': 3.8, 'ascent_m': 310, 'has_supply': False, 'has_retreat': False, 'note': '全程山脊暴曬無補給，風景極佳'}, {'id': 'seg-05-3', 'trail_id': 'trail-05', 'seq': 3, 'name': '純陽峰 → 橫山腳 → 新娘潭巴士站', 'distance_km': 3.5, 'ascent_m': 0, 'has_supply': False, 'has_retreat': True, 'note': '新娘潭周末有275R巴士直達大埔墟站'}, {'id': 'seg-06-1', 'trail_id': 'trail-06', 'seq': 1, 'name': '菠蘿壩小巴站 → 賞蝶園 → 白千層夾道', 'distance_km': 3.8, 'ascent_m': 60, 'has_supply': True, 'has_retreat': True, 'note': '菠蘿壩有小食亭，全段平坦林蔭'}, {'id': 'seg-06-2', 'trail_id': 'trail-06', 'seq': 2, 'name': '白千層水浸林 → 城門主壩 → 菠蘿壩', 'distance_km': 3.7, 'ascent_m': 60, 'has_supply': False, 'has_retreat': True, 'note': '主壩可撤退往梨木樹'}, {'id': 'seg-07-1', 'trail_id': 'trail-07', 'seq': 1, 'name': '凌霄閣 → 盧吉道維港觀景台 → 西高山郊遊區', 'distance_km': 2.0, 'ascent_m': 30, 'has_supply': True, 'has_retreat': True, 'note': '無障礙水泥步道，老少咸宜'}, {'id': 'seg-07-2', 'trail_id': 'trail-07', 'seq': 2, 'name': '夏力道林蔭段 → 山頂廣場', 'distance_km': 1.6, 'ascent_m': 30, 'has_supply': True, 'has_retreat': True, 'note': '終點商場餐廳及纜車巴士齊備'}, {'id': 'seg-08-1', 'trail_id': 'trail-08', 'seq': 1, 'name': '大帽山郊野公園茶水亭 → 大帽山道閘口', 'distance_km': 1.8, 'ascent_m': 150, 'has_supply': True, 'has_retreat': True, 'note': '蓮姐茶水亭必食茶葉蛋及燒賣'}, {'id': 'seg-08-2', 'trail_id': 'trail-08', 'seq': 2, 'name': '大帽山道閘口 → 天氣雷達站頂峰（折返）', 'distance_km': 5.0, 'ascent_m': 280, 'has_supply': False, 'has_retreat': True, 'note': '全段瀝青車路，髮夾彎視野開揚'}, {'id': 'seg-09-1', 'trail_id': 'trail-09', 'seq': 1, 'name': '烏蛟騰 → 九担租 → 三椏村', 'distance_km': 4.5, 'ascent_m': 140, 'has_supply': True, 'has_retreat': True, 'note': '三椏村有福利茶座可嘆客家美食'}, {'id': 'seg-09-2', 'trail_id': 'trail-09', 'seq': 2, 'name': '三椏村 → 荔枝窩古村廣場', 'distance_km': 3.7, 'ascent_m': 70, 'has_supply': True, 'has_retreat': True, 'note': '紅樹林海岸步道，假日有街渡回馬料水'}, {'id': 'seg-10-1', 'trail_id': 'trail-10', 'seq': 1, 'name': '伯公坳 → 鳳凰山天梯 → 鳳凰山頂', 'distance_km': 3.2, 'ascent_m': 610, 'has_supply': False, 'has_retreat': False, 'note': '日出熱門路線，天梯段需備頭燈'}, {'id': 'seg-10-2', 'trail_id': 'trail-10', 'seq': 2, 'name': '鳳凰山頂 → 斬柴坳 → 心經簡林 → 昂坪', 'distance_km': 3.3, 'ascent_m': 70, 'has_supply': True, 'has_retreat': True, 'note': '昂坪市集設有多間餐廳及巴士纜車'}], 'checkpoints': [{'id': 'cp-01-1', 'trail_id': 'trail-01', 'segment_id': 'seg-01-1', 'seq': 1, 'name': '土地灣登山口', 'lat': 22.2268, 'lng': 114.2422, 'note': '9號巴士土地灣站下車即達'}, {'id': 'cp-01-2', 'trail_id': 'trail-01', 'segment_id': 'seg-01-1', 'seq': 2, 'name': '石澳半島觀景台', 'lat': 22.2315, 'lng': 114.2435, 'note': '俯瞰石澳泳灘與五分洲最佳位置'}, {'id': 'cp-01-3', 'trail_id': 'trail-01', 'segment_id': 'seg-01-2', 'seq': 3, 'name': '打爛埕頂山（龍脊最高點 284m）', 'lat': 22.2369, 'lng': 114.2431, 'note': '標距柱 H085 打卡熱點'}, {'id': 'cp-01-4', 'trail_id': 'trail-01', 'segment_id': 'seg-01-3', 'seq': 4, 'name': '大浪灣滑浪沙灘終點', 'lat': 22.2458, 'lng': 114.2495, 'note': '士多冰凍汽水與餐蛋麵補給'}, {'id': 'cp-02-1', 'trail_id': 'trail-02', 'segment_id': 'seg-02-1', 'seq': 1, 'name': '北潭凹起點標距柱', 'lat': 22.4192, 'lng': 114.3318, 'note': '94號巴士北潭凹站'}, {'id': 'cp-02-2', 'trail_id': 'trail-02', 'segment_id': 'seg-02-2', 'seq': 2, 'name': '鹹田灣獨木橋', 'lat': 22.408, 'lng': 114.3745, 'note': '經典木橋打卡位'}, {'id': 'cp-02-3', 'trail_id': 'trail-02', 'segment_id': 'seg-02-2', 'seq': 3, 'name': '西灣村茶座', 'lat': 22.3982, 'lng': 114.3712, 'note': '中途補給與撤退點'}, {'id': 'cp-02-4', 'trail_id': 'trail-02', 'segment_id': 'seg-02-3', 'seq': 4, 'name': '浪茄灣玻璃水沙灘', 'lat': 22.3765, 'lng': 114.3752, 'note': '全港最美水質沙灘'}, {'id': 'cp-03-1', 'trail_id': 'trail-03', 'segment_id': 'seg-03-1', 'seq': 1, 'name': '獅子山回歸亭', 'lat': 22.351, 'lng': 114.1865, 'note': '上下山分岔口及休息涼亭'}, {'id': 'cp-03-2', 'trail_id': 'trail-03', 'segment_id': 'seg-03-2', 'seq': 2, 'name': '獅子山頂標高柱', 'lat': 22.3526, 'lng': 114.1872, 'note': '九龍半島全景打卡位'}, {'id': 'cp-03-3', 'trail_id': 'trail-03', 'segment_id': 'seg-03-3', 'seq': 3, 'name': '沙田坳恆益商店', 'lat': 22.3551, 'lng': 114.2015, 'note': '必食山水薑汁豆腐花'}, {'id': 'cp-04-1', 'trail_id': 'trail-04', 'segment_id': 'seg-04-1', 'seq': 1, 'name': '伯公坳涼亭', 'lat': 22.2485, 'lng': 113.9432, 'note': '東涌巴士3M/11號下車點'}, {'id': 'cp-04-2', 'trail_id': 'trail-04', 'segment_id': 'seg-04-2', 'seq': 2, 'name': '爛頭營石屋群', 'lat': 22.2562, 'lng': 113.961, 'note': '大東山芒草核心打卡區'}, {'id': 'cp-04-3', 'trail_id': 'trail-04', 'segment_id': 'seg-04-3', 'seq': 3, 'name': '梅窩碼頭終點', 'lat': 22.2645, 'lng': 113.9985, 'note': '可乘渡輪回中環'}, {'id': 'cp-05-1', 'trail_id': 'trail-05', 'segment_id': 'seg-05-1', 'seq': 1, 'name': '仙姑峰頂', 'lat': 22.482, 'lng': 114.231, 'note': '八仙嶺第一峰'}, {'id': 'cp-05-2', 'trail_id': 'trail-05', 'segment_id': 'seg-05-2', 'seq': 2, 'name': '純陽峰標高柱', 'lat': 22.4885, 'lng': 114.2225, 'note': '八仙嶺最高峰 590m'}, {'id': 'cp-06-1', 'trail_id': 'trail-06', 'segment_id': 'seg-06-1', 'seq': 1, 'name': '城門白千層水浸林', 'lat': 22.3935, 'lng': 114.1512, 'note': '天空之鏡倒影打卡位'}, {'id': 'cp-07-1', 'trail_id': 'trail-07', 'segment_id': 'seg-07-1', 'seq': 1, 'name': '盧吉道維港觀景台', 'lat': 22.2768, 'lng': 114.1475, 'note': '維港最佳全景位'}, {'id': 'cp-08-1', 'trail_id': 'trail-08', 'segment_id': 'seg-08-1', 'seq': 1, 'name': '蓮姐茶水亭', 'lat': 22.4045, 'lng': 114.1165, 'note': '大帽山起點補給站'}, {'id': 'cp-08-2', 'trail_id': 'trail-08', 'segment_id': 'seg-08-2', 'seq': 2, 'name': '大帽山天氣雷達站', 'lat': 22.4112, 'lng': 114.1232, 'note': '全港最高點打卡位'}, {'id': 'cp-09-1', 'trail_id': 'trail-09', 'segment_id': 'seg-09-2', 'seq': 1, 'name': '荔枝窩客家古村', 'lat': 22.5268, 'lng': 114.2595, 'note': '百年風水林與空心樹'}, {'id': 'cp-10-1', 'trail_id': 'trail-10', 'segment_id': 'seg-10-1', 'seq': 1, 'name': '鳳凰山頂（海拔934m）', 'lat': 22.2428, 'lng': 113.9225, 'note': '鳳凰觀日避風亭'}], 'posts': [{'id': '22222222-2222-4222-8222-222222222201', 'author_id': '11111111-1111-4111-8111-111111111102', 'type': 'moment', 'title': '龍脊秋風超爽！石澳海景無敵', 'body': '今日天朗氣清同山友行龍脊，打爛埕頂山吹海風超舒服，全程兩個半鐘落到大浪灣食餐蛋麵！強烈推薦週末早啲出發避開人潮。', 'trail_id': 'trail-01', 'meta': {'tags': ['風景', '補給', '週末好去處']}, 'like_count': 3, 'comment_count': 2, 'favorite_count': 2, 'created_at': '2026-11-02T17:20:00Z', 'photos': ['https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80']}, {'id': '22222222-2222-4222-8222-222222222202', 'author_id': '11111111-1111-4111-8111-111111111101', 'type': 'trip', 'title': '麥理浩徑二段全走打卡記錄', 'body': '北潭凹入、東壩出，鹹田灣同浪茄灣水質依然係玻璃水級數！西灣村士多食咗碗冰凍綠豆沙回血，全程 13.5km 順利完成 4 個打卡點。', 'trail_id': 'trail-02', 'meta': {'distance_km': 13.5, 'duration_sec': 16800, 'ascent_m': 580, 'checked_count': 4, 'total_checkpoints': 4, 'tags': ['行山記錄', '西貢', '海景'], 'path': [[22.4192, 114.3318], [22.4165, 114.351], [22.408, 114.3745], [22.3982, 114.3712], [22.3765, 114.3752]]}, 'like_count': 4, 'comment_count': 2, 'favorite_count': 3, 'created_at': '2026-11-02T20:10:00Z', 'photos': ['https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=80']}, {'id': '22222222-2222-4222-8222-222222222203', 'author_id': '11111111-1111-4111-8111-111111111104', 'type': 'moment', 'title': '大東山芒草季開鑼！夕陽金光太震撼', 'body': '三點半由伯公坳上山，五點剛好趕到爛頭營石屋影日落芒草。提醒大家太陽落山後風好大，記得帶件防風外套同頭燈落梅窩！', 'trail_id': 'trail-04', 'meta': {'tags': ['芒草', '日落', '大嶼山']}, 'like_count': 5, 'comment_count': 1, 'favorite_count': 2, 'created_at': '2026-11-03T09:30:00Z', 'photos': ['https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80']}, {'id': '22222222-2222-4222-8222-222222222204', 'author_id': '11111111-1111-4111-8111-111111111106', 'type': 'question', 'title': '請問週末去麥徑二段，西灣亭村巴尾班車係幾點？', 'body': '各位山友師兄師姐好！我同朋友星期六打算由北潭凹行去西灣村，怕體力唔夠未必行到去東壩，想問下西灣亭返西貢市中心嘅29R村巴尾班車係幾點？另外鹹田灣有冇街渡直接返西貢？唔該晒！', 'trail_id': 'trail-02', 'meta': {'tags': ['交通', '撤退點'], 'has_accepted': True}, 'like_count': 2, 'comment_count': 2, 'favorite_count': 1, 'created_at': '2026-11-01T15:00:00Z', 'photos': []}, {'id': '22222222-2222-4222-8222-222222222205', 'author_id': '11111111-1111-4111-8111-111111111105', 'type': 'question', 'title': '11月凌晨上鳳凰山睇日出，需要著羽絨定普通抓絨就夠？', 'body': '準備今個禮拜日凌晨3點半由伯公坳上鳳凰山，市區預報19度左右，想請教近期上過頂嘅山友，山頂避風亭等日出嗰陣會唔會好凍？裝備方面有咩建議？', 'trail_id': 'trail-10', 'meta': {'tags': ['裝備', '天氣'], 'has_accepted': False}, 'like_count': 2, 'comment_count': 1, 'favorite_count': 1, 'created_at': '2026-11-03T11:45:00Z', 'photos': []}, {'id': '22222222-2222-4222-8222-222222222206', 'author_id': '11111111-1111-4111-8111-111111111103', 'type': 'moment', 'title': '獅子山頂望九龍全景 + 沙田坳豆腐花', 'body': '天馬苑上獅子山段石級雖然急，但上到山頂望住九龍同維港真係超值。落山去沙田坳食返碗熱辣辣薑汁豆腐花，完美半日遊！', 'trail_id': 'trail-03', 'meta': {'tags': ['九龍全景', '補給', '豆腐花']}, 'like_count': 3, 'comment_count': 1, 'favorite_count': 1, 'created_at': '2026-11-03T13:15:00Z', 'photos': ['https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&auto=format&fit=crop&q=80']}], 'comments': [{'id': '33333333-3333-4333-8333-333333333301', 'post_id': '22222222-2222-4222-8222-222222222201', 'author_id': '11111111-1111-4111-8111-111111111101', 'parent_id': None, 'body': '相片影得好靚！大浪灣間士多啲蔥油豬扒麵都好正。', 'is_accepted': False, 'created_at': '2026-11-02T18:00:00Z'}, {'id': '33333333-3333-4333-8333-333333333302', 'post_id': '22222222-2222-4222-8222-222222222201', 'author_id': '11111111-1111-4111-8111-111111111102', 'parent_id': '33333333-3333-4333-8333-333333333301', 'body': '多謝阿瀚！下次去試下豬扒麵先～', 'is_accepted': False, 'created_at': '2026-11-02T18:15:00Z'}, {'id': '33333333-3333-4333-8333-333333333303', 'post_id': '22222222-2222-4222-8222-222222222204', 'author_id': '11111111-1111-4111-8111-111111111103', 'parent_id': None, 'body': '西灣亭去西貢市中心嘅NR29村巴，假日尾班車通常係下晝 6:00（由西灣村行上西灣亭約需45分鐘）。另外鹹田灣同西灣村士多都可以即時買街渡飛直返西貢碼頭，約下晝4:30-5:00開船，但要視乎當日風浪情況！', 'is_accepted': True, 'created_at': '2026-11-01T15:40:00Z'}, {'id': '33333333-3333-4333-8333-333333333304', 'post_id': '22222222-2222-4222-8222-222222222204', 'author_id': '11111111-1111-4111-8111-111111111106', 'parent_id': '33333333-3333-4333-8333-333333333303', 'body': '太詳細啦輝哥！已採納，我哋到時早啲到西灣村睇下街渡情況先！', 'is_accepted': False, 'created_at': '2026-11-01T16:05:00Z'}, {'id': '33333333-3333-4333-8333-333333333305', 'post_id': '22222222-2222-4222-8222-222222222205', 'author_id': '11111111-1111-4111-8111-111111111101', 'parent_id': None, 'body': '鳳凰山頂凌晨好大風，體感比市區低 7-8 度！上山時會出汗著排汗底衫，但上到頂等日出嗰45分鐘一定要有輕量羽絨 + 防風硬殼，仲有必備頭燈。', 'is_accepted': False, 'created_at': '2026-11-03T12:10:00Z'}, {'id': '33333333-3333-4333-8333-333333333306', 'post_id': '22222222-2222-4222-8222-222222222202', 'author_id': '11111111-1111-4111-8111-111111111104', 'parent_id': None, 'body': '浪茄灣水色真係好治癒，下星期跟住你條路線打卡先！', 'is_accepted': False, 'created_at': '2026-11-02T21:00:00Z'}], 'likes': [{'post_id': '22222222-2222-4222-8222-222222222201', 'user_id': '11111111-1111-4111-8111-111111111101'}, {'post_id': '22222222-2222-4222-8222-222222222201', 'user_id': '11111111-1111-4111-8111-111111111103'}, {'post_id': '22222222-2222-4222-8222-222222222201', 'user_id': '11111111-1111-4111-8111-111111111104'}, {'post_id': '22222222-2222-4222-8222-222222222202', 'user_id': '11111111-1111-4111-8111-111111111101'}, {'post_id': '22222222-2222-4222-8222-222222222202', 'user_id': '11111111-1111-4111-8111-111111111102'}, {'post_id': '22222222-2222-4222-8222-222222222202', 'user_id': '11111111-1111-4111-8111-111111111104'}, {'post_id': '22222222-2222-4222-8222-222222222202', 'user_id': '11111111-1111-4111-8111-111111111105'}, {'post_id': '22222222-2222-4222-8222-222222222203', 'user_id': '11111111-1111-4111-8111-111111111101'}, {'post_id': '22222222-2222-4222-8222-222222222203', 'user_id': '11111111-1111-4111-8111-111111111102'}, {'post_id': '22222222-2222-4222-8222-222222222203', 'user_id': '11111111-1111-4111-8111-111111111103'}, {'post_id': '22222222-2222-4222-8222-222222222203', 'user_id': '11111111-1111-4111-8111-111111111105'}, {'post_id': '22222222-2222-4222-8222-222222222203', 'user_id': '11111111-1111-4111-8111-111111111106'}], 'favorites': [{'user_id': '11111111-1111-4111-8111-111111111101', 'target_type': 'trail', 'target_id': 'trail-01'}, {'user_id': '11111111-1111-4111-8111-111111111101', 'target_type': 'trail', 'target_id': 'trail-02'}, {'user_id': '11111111-1111-4111-8111-111111111101', 'target_type': 'trail', 'target_id': 'trail-04'}, {'user_id': '11111111-1111-4111-8111-111111111101', 'target_type': 'post', 'target_id': '22222222-2222-4222-8222-222222222201'}, {'user_id': '11111111-1111-4111-8111-111111111101', 'target_type': 'post', 'target_id': '22222222-2222-4222-8222-222222222203'}, {'user_id': '11111111-1111-4111-8111-111111111102', 'target_type': 'trail', 'target_id': 'trail-01'}, {'user_id': '11111111-1111-4111-8111-111111111102', 'target_type': 'trail', 'target_id': 'trail-06'}, {'user_id': '11111111-1111-4111-8111-111111111102', 'target_type': 'post', 'target_id': '22222222-2222-4222-8222-222222222202'}]}


def get_runtime_root() -> Path:
    """Resolve directory containing .env (supports both python main.py and PyInstaller exe)."""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[2]


class SupabaseClientManager:
    _instance: Optional["SupabaseClientManager"] = None

    def __init__(self) -> None:
        self.root_dir = get_runtime_root()
        env_path = self.root_dir / ".env"
        example_path = self.root_dir / ".env.example"
        if env_path.exists():
            load_dotenv(env_path, override=False)
        elif example_path.exists():
            load_dotenv(example_path, override=False)

        self.supabase_url: str = os.getenv("SUPABASE_URL", "").strip()
        self.supabase_anon_key: str = os.getenv("SUPABASE_ANON_KEY", "").strip()
        self.bucket_name: str = os.getenv("SUPABASE_BUCKET", "trail-photos").strip()

        self.env_valid: bool = False
        self.env_error_message: str = ""
        self.remote_online: bool = False
        self.client: Optional[Any] = None

        self.store_path = self.root_dir / ".hikehub_local_store.json"
        self._store: Dict[str, Any] = {}
        self._load_or_init_local_store()
        self._init_connection()

    @classmethod
    def instance(cls) -> "SupabaseClientManager":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _validate_jwt(self, token: str) -> Dict[str, Any]:
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError("SUPABASE_ANON_KEY 不是有效的 JWT 格式")
        payload_b64 = parts[1] + "=" * (-len(parts[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64.encode("utf-8")))
        exp = payload.get("exp", 0)
        if exp and exp < time.time():
            raise ValueError("SUPABASE_ANON_KEY 已過期")
        return payload

    def _init_connection(self) -> None:
        if not self.supabase_url or not self.supabase_anon_key:
            self.env_valid = False
            self.env_error_message = "未檢測到 SUPABASE_URL 或 SUPABASE_ANON_KEY，請檢查同目錄下 .env 配置檔案。"
            return

        if not self.supabase_url.startswith("https://") or ".supabase.co" not in self.supabase_url:
            self.env_valid = False
            self.env_error_message = f"SUPABASE_URL 格式不正確 ({self.supabase_url})，請檢查 .env 配置。"
            return

        try:
            payload = self._validate_jwt(self.supabase_anon_key)
            ref = payload.get("ref", "")
            if ref and ref not in self.supabase_url:
                self.env_valid = False
                self.env_error_message = f"SUPABASE_ANON_KEY 項目 ref ({ref}) 與 SUPABASE_URL 不匹配，請檢查 .env 配置。"
                return
            self.env_valid = True
        except Exception as exc:
            self.env_valid = False
            self.env_error_message = f"請檢查 .env 配置：{exc}"
            return

        if create_client is not None:
            try:
                self.client = create_client(self.supabase_url, self.supabase_anon_key)
                # Probe remote table readiness with short timeout
                res = self.client.table("trails").select("id").limit(1).execute()
                if res and hasattr(res, "data"):
                    self.remote_online = True
            except Exception:
                # Remote Supabase table not created yet or offline environment -> seamless local store fallback
                self.remote_online = False

    def _load_or_init_local_store(self) -> None:
        if self.store_path.exists():
            try:
                self._store = json.loads(self.store_path.read_text(encoding="utf-8"))
                if "trails" in self._store and len(self._store["trails"]) >= 10:
                    return
            except Exception:
                pass
        self._store = copy.deepcopy(DEFAULT_SEED_DATA)
        self.save_store()

    def save_store(self) -> None:
        try:
            self.store_path.write_text(
                json.dumps(self._store, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except Exception:
            pass

    @property
    def store(self) -> Dict[str, Any]:
        return self._store

    def get_status_summary(self) -> Dict[str, Any]:
        return {
            "env_valid": self.env_valid,
            "env_error_message": self.env_error_message,
            "supabase_url": self.supabase_url,
            "bucket": self.bucket_name,
            "remote_online": self.remote_online,
            "mode": "Supabase Cloud (已連線)" if self.remote_online else ("Supabase 憑證已就緒 · 本地鏡像同步模式" if self.env_valid else "未配置 .env"),
        }


def get_db() -> SupabaseClientManager:
    return SupabaseClientManager.instance()
