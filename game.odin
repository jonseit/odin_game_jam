package game

import rl "vendor:raylib"

SCREEN_WIDTH_PX :: 1000
SCREEN_HEIGHT_PX :: 1000
NUM_TILES_PER_SIDE :: 20
TILE_LENGTH :: 50
TRACK_LENGTH :: 33
NUM_TRACK_SEGMENTS :: 4
ENEMY_SPEED :: 150

Enemy :: struct {
    position: rl.Vector2,
    track_segment_idx: int,
    finished_track: bool,
}

Tower :: struct {
    position: rl.Vector2
}

Track_Segment :: struct {
    position: rl.Vector2,
    direction: rl.Vector2,
}

track_tiles : [TRACK_LENGTH]rl.Vector2 = {
    { 5, 0 },
    { 5, 1 },
    { 5, 2 },
    { 5, 3 },
    { 5, 4 },
    { 5, 5 },
    { 5, 6 },
    { 5, 7 },
    { 5, 8 },
    { 5, 9 },
    { 5, 10 },
    { 5, 11 },
    { 5, 12 },
    { 6, 12 },
    { 7, 12 },
    { 8, 12 },
    { 9, 12 },
    { 10, 12 },
    { 11, 12 },
    { 12, 12 },
    { 13, 12 },
    { 13, 11 },
    { 13, 10 },
    { 13, 9 },
    { 13, 8 },
    { 13, 7 },
    { 13, 6 },
    { 13, 5 },
    { 13, 4 },
    { 13, 3 },
    { 13, 2 },
    { 13, 1 },
    { 13, 0 },
}

track : [NUM_TRACK_SEGMENTS]Track_Segment = {
    { track_tiles[0] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[12] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[20] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, -1 } },
    { track_tiles[32] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 0 } },
}

enemies: [dynamic]Enemy
towers: [dynamic]Tower

restart :: proc() {
    clear(&enemies)
    append(&enemies, Enemy {
        position = track_tiles[0] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
    append(&enemies, Enemy {
        position = track_tiles[1] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
    append(&enemies, Enemy {
        position = track_tiles[2] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_WIDTH_PX, SCREEN_HEIGHT_PX, "Odin Game Jam")
    rl.InitAudioDevice()
    rl.SetTargetFPS(500)

    restart()

    for !rl.WindowShouldClose() {

        if rl.IsKeyPressed(.R) {
            restart()
        }

        for &enemy in enemies {
            cur_track_segment := track[enemy.track_segment_idx]
            next_track_segment := track[enemy.track_segment_idx + 1]

            if cur_track_segment.direction.y > 0 {
                next_position_y := enemy.position.y + rl.GetFrameTime() * ENEMY_SPEED
                if next_position_y >= next_track_segment.position.y {
                    position_carry_over := next_position_y - enemy.position.y
                    enemy.position.y = next_track_segment.position.y
                    enemy.position.x += position_carry_over * next_track_segment.direction.x
                    enemy.track_segment_idx += 1
                } else {
                    enemy.position.y = next_position_y
                }
            } else if cur_track_segment.direction.y < 0 {
                next_position_y := enemy.position.y - rl.GetFrameTime() * ENEMY_SPEED
                if next_position_y <= next_track_segment.position.y {
                    position_carry_over := enemy.position.y - next_position_y
                    enemy.position.y = next_track_segment.position.y
                    enemy.position.x += position_carry_over * next_track_segment.direction.x
                    enemy.track_segment_idx += 1
                } else {
                    enemy.position.y = next_position_y
                }
            } else if cur_track_segment.direction.x > 0 {
                next_position_x := enemy.position.x + rl.GetFrameTime() * ENEMY_SPEED
                if next_position_x >= next_track_segment.position.x {
                    position_carry_over := next_position_x - enemy.position.x
                    enemy.position.x = next_track_segment.position.x
                    enemy.position.y += position_carry_over * next_track_segment.direction.y
                    enemy.track_segment_idx += 1
                } else {
                    enemy.position.x = next_position_x
                }
            } else if cur_track_segment.direction.x < 0 {
                next_position_x := enemy.position.x - rl.GetFrameTime() * ENEMY_SPEED
                if next_position_x <= next_track_segment.position.x {
                    position_carry_over := enemy.position.x - next_position_x
                    enemy.position.x = next_track_segment.position.y
                    enemy.position.y += position_carry_over * next_track_segment.direction.y
                    enemy.track_segment_idx += 1
                } else {
                    enemy.position.x = next_position_x
                }
            }

            if enemy.track_segment_idx == NUM_TRACK_SEGMENTS - 1 {
                enemy.finished_track = true
            }
        }

        for enemy, idx in enemies {
            if enemy.finished_track {
                unordered_remove(&enemies, idx)
            }
        }

        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.GRAY)

        for tile in track_tiles {
            tile_rec := rl.Rectangle {
                tile.x * TILE_LENGTH,
                tile.y * TILE_LENGTH,
                TILE_LENGTH,
                TILE_LENGTH,
            }

            rl.DrawRectangleRec(tile_rec, rl.BLUE)
        }

        for enemy in enemies {
            rl.DrawCircleV(enemy.position, 15, rl.RED)
        }

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}