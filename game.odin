package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

SCREEN_SIZE_PX :: 960
SCREEN_SIZE :: 240
NUM_TILES_PER_SIDE :: 10
TILE_SIZE :: 24
NUM_TRACK_TILES :: 29
NUM_TRACK_SEGMENTS :: 11
TOWER_RADIUS :: 10
SIGHT_RADIUS :: 60
DOUGHNUT_RADIUS :: 8
GLAZE_RADIUS :: 4
DOUGHNUT_SPEED :: 40
GLAZE_SPEED :: 100
RELOADING_TIME :: 2.5
NEW_DOUGHNUT_TIME_INTERVAL :: 1
NUM_CONVEYER_FRAMES :: 3
CONVEYER_FRAME_LENGTH :: 0.05

Orientation :: enum {
    North,
    East,
    South,
    West,
}

Doughnut :: struct {
    position: rl.Vector2,
    track_segment_idx: int,
    is_glazed: bool,
    is_finished: bool,
    glaze_pointer_counter: int,
}

Tower :: struct {
    position: rl.Vector2,
    reloading_timer: f32,
}

Glaze :: struct {
    position: rl.Vector2,
    direction: rl.Vector2,
    target_doughnut: ^Doughnut,
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
    .North = { { 0, TILE_SIZE }, 90 },
    .East = { { TILE_SIZE, TILE_SIZE }, 180 },
    .South = { { TILE_SIZE, 0 }, 270 },
    .West = { { 0, 0 }, 0 },
}

track_tiles : [NUM_TRACK_TILES]Track_Tile = {
    { { 0, 2 }, .East },
    { { 1, 2 }, .South },
    { { 1, 3 }, .South },
    { { 1, 4 }, .South },
    { { 1, 5 }, .East },
    { { 2, 5 }, .East },
    { { 3, 5 }, .East },
    { { 4, 5 }, .North },
    { { 4, 4 }, .North },
    { { 4, 3 }, .North },
    { { 4, 2 }, .North },
    { { 4, 1 }, .East },
    { { 5, 1 }, .East },
    { { 6, 1 }, .East },
    { { 7, 1 }, .East },
    { { 8, 1 }, .South },
    { { 8, 2 }, .South },
    { { 8, 3 }, .South },
    { { 8, 4 }, .West },
    { { 7, 4 }, .South },
    { { 7, 5 }, .South },
    { { 7, 6 }, .South },
    { { 7, 7 }, .South },
    { { 7, 8 }, .West },
    { { 6, 8 }, .West },
    { { 5, 8 }, .West },
    { { 4, 8 }, .West },
    { { 3, 8 }, .South },
    { { 3, 9 }, .South },
}

track : [NUM_TRACK_SEGMENTS]Track_Segment = {
    { rl.Vector2{ -1, 2 } * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 1, 0 } },
    { track_tiles[1].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 0, 1 } },
    { track_tiles[4].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 1, 0 } },
    { track_tiles[7].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 0, -1 } },
    { track_tiles[11].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 1, 0 } },
    { track_tiles[15].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 0, 1 } },
    { track_tiles[18].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { -1, 0 } },
    { track_tiles[19].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 0, 1 } },
    { track_tiles[23].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { -1, 0 } },
    { track_tiles[27].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 0, 1 } },
    { rl.Vector2{ 3, 10 } * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 }, { 0, 0 } },
}

doughnuts: [dynamic]Doughnut
towers: [dynamic]Tower
glazes: [dynamic]Glaze
doughnut_timer: f32
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
        TILE_SIZE,
        TILE_SIZE,
    }

    dest := rl.Rectangle {
        tile.position.x * TILE_SIZE,
        tile.position.y * TILE_SIZE,
        TILE_SIZE,
        TILE_SIZE,
    }

    rl.DrawTexturePro(texture, source, dest, tile_orientations[tile.orientation].origin, tile_orientations[tile.orientation].rotation, rl.WHITE)
}

restart :: proc() {
    clear(&doughnuts)
//    append(&doughnuts, Doughnut {
//        position = track_tiles[2].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 },
//        track_segment_idx = 0,
//    })
//    append(&doughnuts, Doughnut {
//        position = track_tiles[1].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 },
//        track_segment_idx = 0,
//    })
//    append(&doughnuts, Doughnut {
//        position = track[0].position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 },
//        track_segment_idx = 0,
//    })
//    append(&doughnuts, Doughnut {
//        position = rl.Vector2{ -1, 2 } * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 },
//        track_segment_idx = 0,
//    })

    clear(&towers)
    clear(&glazes)
}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_SIZE_PX, SCREEN_SIZE_PX, "Glaze the Doughnut!")
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
                math.floor_f32(mp.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
                math.floor_f32(mp.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
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
                    if track_tile.position * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 } == tower_pos {
                        is_valid_pos = false
                        break
                    }
                }
            }
            if is_valid_pos {
                append(&towers, Tower {
                    position = tower_pos,
                })
            }
        }

        doughnut_timer += rl.GetFrameTime()
        if doughnut_timer >= NEW_DOUGHNUT_TIME_INTERVAL {
            append(&doughnuts, Doughnut {
                position = rl.Vector2{ -1, 2 } * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 },
                track_segment_idx = 0,
            })
            doughnut_timer = 0
        }

        for &doughnut in doughnuts {
            if !doughnut.is_finished {
                cur_track_segment := track[doughnut.track_segment_idx]
                next_track_segment := track[doughnut.track_segment_idx + 1]

                if doughnut.position.x < 0 { // special case for when doughnut is out of screen at track start
                    next_position_x := doughnut.position.x + rl.GetFrameTime() * DOUGHNUT_SPEED
                    if next_position_x >= 0 {
                        position_carry_over := doughnut.position.x - next_position_x
                        doughnut.position.x = position_carry_over * next_track_segment.direction.x
                    } else {
                        doughnut.position.x = next_position_x
                    }
                } else if cur_track_segment.direction.y > 0 {
                    next_position_y := doughnut.position.y + rl.GetFrameTime() * DOUGHNUT_SPEED
                    if next_position_y >= next_track_segment.position.y {
                        position_carry_over := next_position_y - doughnut.position.y
                        doughnut.position.y = next_track_segment.position.y
                        doughnut.position.x += position_carry_over * next_track_segment.direction.x
                        doughnut.track_segment_idx += 1
                    } else {
                        doughnut.position.y = next_position_y
                    }
                } else if cur_track_segment.direction.y < 0 {
                    next_position_y := doughnut.position.y - rl.GetFrameTime() * DOUGHNUT_SPEED
                    if next_position_y <= next_track_segment.position.y {
                        position_carry_over := doughnut.position.y - next_position_y
                        doughnut.position.y = next_track_segment.position.y
                        doughnut.position.x += position_carry_over * next_track_segment.direction.x
                        doughnut.track_segment_idx += 1
                    } else {
                        doughnut.position.y = next_position_y
                    }
                } else if cur_track_segment.direction.x > 0 {
                    next_position_x := doughnut.position.x + rl.GetFrameTime() * DOUGHNUT_SPEED
                    if next_position_x >= next_track_segment.position.x {
                        position_carry_over := next_position_x - doughnut.position.x
                        doughnut.position.x = next_track_segment.position.x
                        doughnut.position.y += position_carry_over * next_track_segment.direction.y
                        doughnut.track_segment_idx += 1
                    } else {
                        doughnut.position.x = next_position_x
                    }
                } else if cur_track_segment.direction.x < 0 {
                    next_position_x := doughnut.position.x - rl.GetFrameTime() * DOUGHNUT_SPEED
                    if next_position_x <= next_track_segment.position.x {
                        position_carry_over := doughnut.position.x - next_position_x
                        doughnut.position.x = next_track_segment.position.x
                        doughnut.position.y += position_carry_over * next_track_segment.direction.y
                        doughnut.track_segment_idx += 1
                    } else {
                        doughnut.position.x = next_position_x
                    }
                }

                if doughnut.track_segment_idx == NUM_TRACK_SEGMENTS - 1 {
                    doughnut.is_finished = true
                }
            }
        }

        for &tower in towers {
            if tower.reloading_timer <= 0 {
                for &doughnut in doughnuts {
                    if !doughnut.is_glazed && rl.CheckCollisionCircles(tower.position, SIGHT_RADIUS, doughnut.position, DOUGHNUT_RADIUS) {
                        glaze_dir := linalg.normalize(doughnut.position - tower.position)
                        append(&glazes, Glaze {
                            position = tower.position,
                            direction = glaze_dir,
                            target_doughnut = &doughnut,
                        })
                        doughnut.glaze_pointer_counter += 1

                        tower.reloading_timer = RELOADING_TIME
                        break
                    }
                }
            } else {
                tower.reloading_timer -= rl.GetFrameTime()
            }
        }

        outer: for &glaze, idx in glazes {
            if glaze.position.x + GLAZE_RADIUS * 6 < 0 ||
            glaze.position.x > SCREEN_SIZE + GLAZE_RADIUS * 6 ||
            glaze.position.y + GLAZE_RADIUS * 6 < 0 ||
            glaze.position.y > SCREEN_SIZE + GLAZE_RADIUS * 6 {
                glaze.target_doughnut^.glaze_pointer_counter -= 1
                unordered_remove(&glazes, idx)
                continue
            }

            for &doughnut in doughnuts {
                if !doughnut.is_glazed && rl.CheckCollisionCircles(glaze.position, GLAZE_RADIUS, doughnut.position, DOUGHNUT_RADIUS) {
                    doughnut.is_glazed = true
                    glaze.target_doughnut^.glaze_pointer_counter -= 1
                    unordered_remove(&glazes, idx)
                    continue outer
                }
            }

            target_doughnut := glaze.target_doughnut^
            if !target_doughnut.is_glazed {
                glaze.direction = linalg.normalize(target_doughnut.position - glaze.position)
            }
            glaze.position += rl.GetFrameTime() * GLAZE_SPEED * glaze.direction
        }

        for &doughnut, idx in doughnuts {
            if doughnut.is_finished && doughnut.glaze_pointer_counter == 0 {
                ordered_remove(&doughnuts, idx)
            }
        }

        // Rendering
        rl.BeginDrawing()
        rl.BeginMode2D(camera)

        for x in 0 ..< NUM_TILES_PER_SIDE {
            for y in 0 ..< NUM_TILES_PER_SIDE {
                rl.DrawTextureV(tile_texture, { f32(x), f32(y) } * TILE_SIZE, rl.WHITE)
            }
        }

        mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        highlight_rec := rl.Rectangle {
            math.floor_f32(mp.x / TILE_SIZE) * TILE_SIZE,
            math.floor_f32(mp.y / TILE_SIZE) * TILE_SIZE,
            TILE_SIZE,
            TILE_SIZE,
        }
        rl.DrawRectangleRec(highlight_rec, { 0, 228, 48, 100 })

        update_conveyer_animation_values()
        for tile in track_tiles {
            draw_conveyer_animation(tile, conveyor_texture)
        }

        for tower in towers {
            rl.DrawTextureV(tower_texture, tower.position - { TOWER_RADIUS, TOWER_RADIUS }, rl.WHITE)
            rl.DrawCircleV(tower.position, SIGHT_RADIUS, { 0, 228, 48, 40 })
        }

        for doughnut in doughnuts {
            if !doughnut.is_finished {
                if doughnut.is_glazed {
                    rl.DrawTextureV(doughnut_glazed_texture, doughnut.position - { DOUGHNUT_RADIUS, DOUGHNUT_RADIUS }, rl.WHITE)
                } else {
                    rl.DrawTextureV(doughnut_unglazed_texture, doughnut.position - { DOUGHNUT_RADIUS, DOUGHNUT_RADIUS }, rl.WHITE)
                }
            }
        }

        for glaze in glazes {
            rl.DrawTextureV(glaze_texture, glaze.position - { GLAZE_RADIUS, GLAZE_RADIUS }, rl.WHITE)
        }

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    fmt.printfln("glazes array length: %v", len(glazes)) // debug
    fmt.printfln("dougnut array length: %v", len(doughnuts)) // debug

    rl.UnloadTexture(tower_texture)
    rl.UnloadTexture(glaze_texture)
    rl.UnloadTexture(doughnut_unglazed_texture)
    rl.UnloadTexture(doughnut_glazed_texture)
    rl.UnloadTexture(conveyor_texture)
    rl.UnloadTexture(tile_texture)

    rl.CloseAudioDevice()
    rl.CloseWindow()
}