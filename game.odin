package game

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
ENEMY_SPEED :: 40
PROJECTILE_SPEED :: 100
RELOADING_TIME :: 2.5
NUM_CONVEYER_FRAMES :: 3
CONVEYER_FRAME_LENGTH :: 0.05

Orientation :: enum {
    North,
    East,
    South,
    West,
}

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

Tile_Orientation :: struct {
    origin: rl.Vector2,
    rotation: f32,
}

Track_Tile :: struct {
    position: rl.Vector2,
    orientation : Orientation,
}

Track_Segment :: struct {
    position: rl.Vector2,
    direction: rl.Vector2,
}

tile_orientations := [Orientation]Tile_Orientation {
    .North = { { 0, TILE_LENGTH }, 90 },
    .East = { { TILE_LENGTH, TILE_LENGTH }, 180 },
    .South = { { TILE_LENGTH, 0 }, 270 },
    .West = { { 0, 0 }, 0 },
}

track_tiles : [NUM_TRACK_TILES]Track_Tile = {
    { { 0, 2 }, .East},
    { { 1, 2 }, .South},
    { { 1, 3 }, .South},
    { { 1, 4 }, .South},
    { { 1, 5 }, .East},
    { { 2, 5 }, .East},
    { { 3, 5 }, .East},
    { { 4, 5 }, .North},
    { { 4, 4 }, .North},
    { { 4, 3 }, .North},
    { { 4, 2 }, .North},
    { { 4, 1 }, .East},
    { { 5, 1 }, .East},
    { { 6, 1 }, .East},
    { { 7, 1 }, .East},
    { { 8, 1 }, .South},
    { { 8, 2 }, .South},
    { { 8, 3 }, .South},
    { { 8, 4 }, .West},
    { { 7, 4 }, .South},
    { { 7, 5 }, .South},
    { { 7, 6 }, .South},
    { { 7, 7 }, .South},
    { { 7, 8 }, .West},
    { { 6, 8 }, .West},
    { { 5, 8 }, .West},
    { { 4, 8 }, .West},
    { { 3, 8 }, .South},
    { { 3, 9 }, .South},
}

track : [NUM_TRACK_SEGMENTS]Track_Segment = {
    { track_tiles[0].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[1].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[4].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[7].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, -1 } },
    { track_tiles[11].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 1, 0 } },
    { track_tiles[15].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[18].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { -1, 0 } },
    { track_tiles[19].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[23].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { -1, 0 } },
    { track_tiles[27].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 1 } },
    { track_tiles[28].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 }, { 0, 0 } },
}

enemies: [dynamic]Enemy
towers: [dynamic]Tower
projectiles: [dynamic]Projectile
conveyer_current_frame: int
conveyer_frame_timer: f32

update_conveyer_animation_values :: proc() {
    conveyer_frame_timer += rl.GetFrameTime()

    for conveyer_frame_timer > CONVEYER_FRAME_LENGTH {
        conveyer_current_frame += 1
        conveyer_frame_timer -= CONVEYER_FRAME_LENGTH

        if conveyer_current_frame == NUM_CONVEYER_FRAMES {
            conveyer_current_frame = 0
        }
    }
}

draw_conveyer_animation :: proc(tile: Track_Tile, texture: rl.Texture2D) {
    source := rl.Rectangle {
        f32(conveyer_current_frame),
        0,
        TILE_LENGTH,
        TILE_LENGTH,
    }

    dest := rl.Rectangle {
        tile.position.x * TILE_LENGTH,
        tile.position.y * TILE_LENGTH,
        TILE_LENGTH,
        TILE_LENGTH,
    }

    rl.DrawTexturePro(texture, source, dest, tile_orientations[tile.orientation].origin, tile_orientations[tile.orientation].rotation, rl.WHITE)
}

restart :: proc() {
    clear(&enemies)
    append(&enemies, Enemy {
        position = track_tiles[2].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
    append(&enemies, Enemy {
        position = track_tiles[1].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
        track_segment_idx = 0,
    })
    append(&enemies, Enemy {
        position = track_tiles[0].position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 },
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
    conveyor_texture := rl.LoadTexture("assets/conveyor.png")
    tile_texture := rl.LoadTexture("assets/tile.png")

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
                    if track_tile.position * TILE_LENGTH + { TILE_LENGTH / 2, TILE_LENGTH / 2 } == tower_pos {
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
        rl.BeginMode2D(camera)

        for x in 0..<NUM_TILES_PER_SIDE {
            for y in 0..<NUM_TILES_PER_SIDE {
                rl.DrawTextureV(tile_texture, { f32(x), f32(y) } * TILE_LENGTH, rl.WHITE)
            }
        }

        update_conveyer_animation_values()
        for tile in track_tiles {
            draw_conveyer_animation(tile, conveyor_texture)
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
    rl.UnloadTexture(conveyor_texture)
    rl.UnloadTexture(tile_texture)

    rl.CloseAudioDevice()
    rl.CloseWindow()
}