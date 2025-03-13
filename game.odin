package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

SCREEN_LENGHT_PX :: 960
SCREEN_SIZE :: 240
NUM_TILES_PER_SIDE :: 10
TILE_LENGTH :: 24
NUM_TRACK_TILES :: 29
NUM_TRACK_SEGMENTS :: 11
TOWER_RADIUS :: 10
DOUGHNUT_RADIUS :: 8
GLAZE_RADIUS :: 4
ENEMY_SPEED :: 50
PROJECTILE_SPEED :: 100
RELOADING_TIME :: 2.5

Enemy :: struct {
    position: rl.Vector2,
    track_segment_idx: int,
    is_hit: bool,
    is_finished: bool,
}

Tower :: struct {
    position: rl.Vector2,
    sight_radius: f32,
    reloading_timer: f32,
}

Projectile :: struct {
    position: rl.Vector2,
    direction: rl.Vector2,
    target_enemy: ^Enemy,
}

Track_Segment :: struct {
    position: rl.Vector2,
    direction: rl.Vector2,
}

track_tiles : [NUM_TRACK_TILES]rl.Vector2 = {
    { 0, 2 },
    { 1, 2 },
    { 1, 3 },
    { 1, 4 },
    { 1, 5 },
    { 2, 5 },
    { 3, 5 },
    { 4, 5 },
    { 4, 4 },
    { 4, 3 },
    { 4, 2 },
    { 4, 1 },
    { 5, 1 },
    { 6, 1 },
    { 7, 1 },
    { 8, 1 },
    { 8, 2 },
    { 8, 3 },
    { 8, 4 },
    { 7, 4 },
    { 7, 5 },
    { 7, 6 },
    { 7, 7 },
    { 7, 8 },
    { 6, 8 },
    { 5, 8 },
    { 4, 8 },
    { 3, 8 },
    { 3, 9 },
}

track : [NUM_TRACK_SEGMENTS]Track_Segment = {
    { track_tiles[0] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[1] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[4] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[7] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, -1 } },
    { track_tiles[11] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[15] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[18] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { -1, 0 } },
    { track_tiles[19] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[23] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { -1, 0 } },
    { track_tiles[27] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[28] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 0 } },
}

enemies: [dynamic]Enemy
towers: [dynamic]Tower
projectiles: [dynamic]Projectile

restart :: proc() {
    clear(&enemies)
    append(&enemies, Enemy {
        position = track_tiles[2] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
    append(&enemies, Enemy {
        position = track_tiles[1] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
    append(&enemies, Enemy {
        position = track_tiles[0] * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })

    clear(&towers)
    clear(&projectiles)
}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_LENGHT_PX, SCREEN_LENGHT_PX, "Glaze the Doughnut!")
    rl.InitAudioDevice()
    rl.SetTargetFPS(500)

    tower_texture := rl.LoadTexture("assets/tower.png")
    glaze_texture := rl.LoadTexture("assets/glaze.png")
    doughnut_unglazed_texture := rl.LoadTexture("assets/doughnut_unglazed.png")
    doughnut_glazed_texture := rl.LoadTexture("assets/doughnut_glazed.png")

    restart()

    for !rl.WindowShouldClose() {
        camera := rl.Camera2D {
            zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE)
        }

        if rl.IsKeyPressed(.R) {
            restart()
        }

        if rl.IsMouseButtonPressed(.LEFT) {
            mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
            tower_pos := rl.Vector2 {
                math.floor_f32(mp.x / TILE_LENGTH) * TILE_LENGTH + TILE_LENGTH / 2,
                math.floor_f32(mp.y / TILE_LENGTH) * TILE_LENGTH + TILE_LENGTH / 2,
            }
            is_valid_pos := true
            for tower in towers {
                if tower.position == tower_pos {
                    is_valid_pos = false
                    break
                }
            }
            if is_valid_pos {
                for track_tile in track_tiles {
                    if track_tile * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 } == tower_pos {
                        is_valid_pos = false
                        break
                    }
                }
            }
            if is_valid_pos { //TODO make this check more efficient (e.g. use 2D bool array to track which tiles are free)
                append(&towers, Tower {
                    position = tower_pos,
                    sight_radius = 60,
                })
            }
        }

        for &enemy in enemies {
            if !enemy.is_finished {
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
                        enemy.position.x = next_track_segment.position.x
                        enemy.position.y += position_carry_over * next_track_segment.direction.y
                        enemy.track_segment_idx += 1
                    } else {
                        enemy.position.x = next_position_x
                    }
                }

                if enemy.track_segment_idx == NUM_TRACK_SEGMENTS - 1 {
                    enemy.is_finished = true
                }
            }
        }

        for &tower in towers {
            if tower.reloading_timer <= 0 {
                for &enemy in enemies {
                    if !enemy.is_hit && rl.CheckCollisionCircles(tower.position, tower.sight_radius, enemy.position, DOUGHNUT_RADIUS) {
                        projectile_dir := linalg.normalize(enemy.position - tower.position)
                        append(&projectiles, Projectile {
                            position = tower.position,
                            direction = projectile_dir,
                            target_enemy = &enemy,
                        })

                        tower.reloading_timer = RELOADING_TIME
                        break
                    }
                }
            } else {
                tower.reloading_timer -= rl.GetFrameTime()
            }
        }

        outer: for &projectile, idx in projectiles {
            if projectile.position.x + GLAZE_RADIUS * 6 < 0 ||
            projectile.position.x > SCREEN_SIZE * GLAZE_RADIUS * 6 ||
            projectile.position.y + GLAZE_RADIUS * 6 < 0 ||
            projectile.position.y > SCREEN_SIZE * GLAZE_RADIUS * 6 {
                unordered_remove(&projectiles, idx)
                continue
            }

            for &enemy in enemies {
                if !enemy.is_hit && rl.CheckCollisionCircles(projectile.position, GLAZE_RADIUS, enemy.position, DOUGHNUT_RADIUS) {
                    enemy.is_hit = true
                    unordered_remove(&projectiles, idx)
                    continue outer
                }
            }

            target_enemy := projectile.target_enemy^
            if !target_enemy.is_hit {
                projectile.direction = linalg.normalize(target_enemy.position - projectile.position)
            }
            projectile.position += rl.GetFrameTime() * PROJECTILE_SPEED * projectile.direction
        }

        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.GRAY)

        rl.BeginMode2D(camera)

        for tile in track_tiles {
            tile_rec := rl.Rectangle {
                tile.x * TILE_LENGTH,
                tile.y * TILE_LENGTH,
                TILE_LENGTH,
                TILE_LENGTH,
            }

            rl.DrawRectangleRec(tile_rec, rl.BLUE)
        }

        mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        highlight_rec := rl.Rectangle {
            math.floor_f32(mp.x / TILE_LENGTH) * TILE_LENGTH,
            math.floor_f32(mp.y / TILE_LENGTH) * TILE_LENGTH,
            TILE_LENGTH,
            TILE_LENGTH,
        }
        rl.DrawRectangleRec(highlight_rec, { 0, 228, 48, 100 })

        for tower in towers {
            rl.DrawTextureV(tower_texture, tower.position - { TOWER_RADIUS, TOWER_RADIUS }, rl.WHITE)
            rl.DrawCircleV(tower.position, tower.sight_radius, { 0, 228, 48, 40 })
        }

        for enemy in enemies {
            if !enemy.is_finished {
                if enemy.is_hit {
                    rl.DrawTextureV(doughnut_glazed_texture, enemy.position - { DOUGHNUT_RADIUS, DOUGHNUT_RADIUS }, rl.WHITE)
                } else {
                    rl.DrawTextureV(doughnut_unglazed_texture, enemy.position - { DOUGHNUT_RADIUS, DOUGHNUT_RADIUS }, rl.WHITE)
                }
            }
        }

        for projectile in projectiles {
            rl.DrawTextureV(glaze_texture, projectile.position - { GLAZE_RADIUS, GLAZE_RADIUS }, rl.WHITE)
        }

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.UnloadTexture(tower_texture)
    rl.UnloadTexture(glaze_texture)
    rl.UnloadTexture(doughnut_unglazed_texture)
    rl.UnloadTexture(doughnut_glazed_texture)

    rl.CloseAudioDevice()
    rl.CloseWindow()
}