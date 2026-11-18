# 에셋 배치 가이드 (`res://assets/`)

이 폴더에 아트 리소스(`.png`, `.webp`, `.svg`, `.jpg`)를 넣으면 `AssetManager`가 자동으로 인식해 기본 벡터/도형 폴백을 실제 에셋으로 교체합니다.

## 권장 경로 및 파일명 규칙

### 1. 배경 및 UI (`assets/ui/`)
- `title_bg.png` — 타이틀 화면 배경 (권장 1920x1080)
- `management_bg.png` — 내정 페이즈 배경 (권장 1920x1080)
- `town_bg.png` — 마을 관리 페이즈 배경 (권장 1920x1080)
- `dungeon_bg.png` — 던전 탐험 지도 배경 (권장 1920x1080)
- `offense_bg.png` — 3x3 오펜스 전투 배경 (권장 1920x1080)
- `defense_bg.png` — 성벽 디펜스 전장 배경 (권장 1920x1080)
- `wall_texture.png` — 성벽 구조물 텍스처 (권장 180x740)

### 2. 영웅 초상화 / 전투 스프라이트
- `assets/heroes/portraits/<hero_id>.png` — 여관/술집/파티 HUD 초상화 (예: `hero_named_leon.png`, 권장 256x256)
- `assets/heroes/sprites/<hero_id>.png` — 3x3 오펜스 / 성벽 디펜스 배치 스프라이트 (권장 128x128)
  - 또는 영웅 JSON(`data/heroes/*.json`)에 `"portrait_path"`, `"sprite_path"`를 직접 지정할 수 있습니다.

### 3. 적 몬스터 (`assets/enemies/`)
- `assets/enemies/<enemy_id>.png` 또는 타입별 폴백(`normal.png`, `elite.png`, `siege.png`, `boss.png`)
  - 또는 `data/enemies.json`에 `"sprite_path"` 지정 가능 (권장 128x128)

### 4. 장비 / 아이템 / 타워 / 속성 / 타일
- `assets/equipments/<equip_id>.png` (권장 64x64)
- `assets/items/<item_id>.png` (권장 64x64)
- `assets/towers/<tower_id>.png` 또는 `base_tower.png` (권장 96x96)
- `assets/elements/<element_id_소문자>.png` (`fire.png`, `ice.png`, `lightning.png`, `earth.png`, `wind.png`, `light.png`, `dark.png`)
- `assets/tiles/<tile_key>.png` (`tile_wall.png`, `tile_boss.png`, `tile_outpost.png`, `tile_treasure.png`, `tile_supply.png`, `tile_event.png`, `tile_portal.png`, `tile_exit.png`, `tile_player.png`)
- `assets/events/<event_id>.png` — 내정 정책 이벤트 일러스트 (또는 JSON의 `"illustration_path"`)
