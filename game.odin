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
SIGHT_RADIUS :: 50
DOUGHNUT_RADIUS :: 8
GLAZE_RADIUS :: 4
GLAZE_SPEED :: 100
RELOADING_TIME :: 2.5
NUM_CONVEYER_FRAMES :: 3
CONVEYER_FRAME_LENGTH :: 0.05
NUM_LEVELS :: 5

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

Level :: struct {
    doughnut_time_interval: f32,
    doughnut_speed: f32,
    max_num_doughnuts: int,
    tower_budget: int,
}

levels := [NUM_LEVELS]Level {
    { 1, 40, 20, 2 },
    { 0.8, 50, 30, 1 },
    { 0.6, 60, 40, 1 },
    { 0.45, 70, 50, 1 },
    { 0.3, 80, 60, 1 },
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
doughnut_counter: int
conveyer_current_frame: int
conveyer_frame_timer: f32
started: bool
game_finished: bool
tower_budget: int
current_level_index: int

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

check_tower_pos_valid :: proc(mp: rl.Vector2) -> (bool, rl.Vector2) {
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
    return is_valid_pos, tower_pos
}

restart :: proc() {
    clear(&doughnuts)
    clear(&towers)
    clear(&glazes)
    current_level_index = -1
    doughnut_counter = 0
    tower_budget = 0
    started = false
    game_finished = false
}

finish_level :: proc() {
    clear(&doughnuts)
    clear(&glazes)
    doughnut_counter = 0
    started = false
}

init_level :: proc() {
    current_level_index += 1
    tower_budget += levels[current_level_index].tower_budget
}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_SIZE_PX, SCREEN_SIZE_PX, "Glaze the Doughnut!")
    rl.SetTargetFPS(500)

    tower_texture := rl.LoadTexture("assets/tower.png")
    glaze_texture := rl.LoadTexture("assets/glaze.png")
    doughnut_unglazed_texture := rl.LoadTexture("assets/doughnut_unglazed.png")
    doughnut_glazed_texture := rl.LoadTexture("assets/doughnut_glazed.png")
    conveyor_texture := rl.LoadTexture("assets/conveyor.png")
    tile_texture := rl.LoadTexture("assets/tile.png")

    restart()
    init_level()

    for !rl.WindowShouldClose() {
        camera := rl.Camera2D {
            zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE)
        }

        if rl.IsKeyPressed(.R) {
            restart()
            init_level()
        }

        if !game_finished {
            if tower_budget > 0 && rl.IsMouseButtonPressed(.LEFT) {
                mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
                is_valid_pos, tower_pos := check_tower_pos_valid(mp)
                if is_valid_pos {
                    append(&towers, Tower {
                        position = tower_pos,
                    })
                    tower_budget -= 1
                }
            }

            if !started {
                if current_level_index < NUM_LEVELS && rl.IsKeyPressed(.SPACE) {
                    started = true
                }
            } else {
                doughnut_timer += rl.GetFrameTime()
                if doughnut_counter < levels[current_level_index].max_num_doughnuts &&
                doughnut_timer >= levels[current_level_index].doughnut_time_interval {
                    append(&doughnuts, Doughnut {
                        position = rl.Vector2{ -1, 2 } * TILE_SIZE + { TILE_SIZE / 2, TILE_SIZE / 2 },
                        track_segment_idx = 0,
                    })
                    doughnut_counter += 1
                    doughnut_timer = 0
                }

                for &doughnut in doughnuts {
                    if !doughnut.is_finished {
                        cur_track_segment := track[doughnut.track_segment_idx]
                        next_track_segment := track[doughnut.track_segment_idx + 1]
                        doughnut_speed := levels[current_level_index].doughnut_speed

                        if doughnut.position.x < 0 {
                            // special case for when doughnut is out of screen at track start
                            next_position_x := doughnut.position.x + rl.GetFrameTime() * doughnut_speed
                            doughnut.position.x = next_position_x
                        } else if cur_track_segment.direction.y > 0 {
                            next_position_y := doughnut.position.y + rl.GetFrameTime() * doughnut_speed
                            if next_position_y >= next_track_segment.position.y {
                                position_carry_over := next_position_y - next_track_segment.position.y
                                doughnut.position.y = next_track_segment.position.y
                                doughnut.position.x += position_carry_over * next_track_segment.direction.x
                                doughnut.track_segment_idx += 1
                            } else {
                                doughnut.position.y = next_position_y
                            }
                        } else if cur_track_segment.direction.y < 0 {
                            next_position_y := doughnut.position.y - rl.GetFrameTime() * doughnut_speed
                            if next_position_y <= next_track_segment.position.y {
                                position_carry_over := next_track_segment.position.y - next_position_y
                                doughnut.position.y = next_track_segment.position.y
                                doughnut.position.x += position_carry_over * next_track_segment.direction.x
                                doughnut.track_segment_idx += 1
                            } else {
                                doughnut.position.y = next_position_y
                            }
                        } else if cur_track_segment.direction.x > 0 {
                            next_position_x := doughnut.position.x + rl.GetFrameTime() * doughnut_speed
                            if next_position_x >= next_track_segment.position.x {
                                position_carry_over := next_position_x - next_track_segment.position.x
                                doughnut.position.x = next_track_segment.position.x
                                doughnut.position.y += position_carry_over * next_track_segment.direction.y
                                doughnut.track_segment_idx += 1
                            } else {
                                doughnut.position.x = next_position_x
                            }
                        } else if cur_track_segment.direction.x < 0 {
                            next_position_x := doughnut.position.x - rl.GetFrameTime() * doughnut_speed
                            if next_position_x <= next_track_segment.position.x {
                                position_carry_over := next_track_segment.position.x - next_position_x
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
                        unordered_remove(&glazes, idx)
                        continue
                    }

                    for &doughnut in doughnuts {
                        if !doughnut.is_glazed && rl.CheckCollisionCircles(glaze.position, GLAZE_RADIUS, doughnut.position, DOUGHNUT_RADIUS) {
                            doughnut.is_glazed = true
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
            }

            if started &&
            doughnut_counter == levels[current_level_index].max_num_doughnuts &&
            doughnuts[len(doughnuts) - 1].is_finished {
                finish_level()
                if current_level_index < NUM_LEVELS - 1 {
                    init_level()
                } else {
                    game_finished = true
                }
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

        if (started) {
            update_conveyer_animation_values()
        }
        for tile in track_tiles {
            draw_conveyer_animation(tile, conveyor_texture)
        }

        if !game_finished {
            mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
            is_valid_pos, tower_pos := check_tower_pos_valid(mp)
            highlight_rec := rl.Rectangle {
                math.floor_f32(mp.x / TILE_SIZE) * TILE_SIZE,
                math.floor_f32(mp.y / TILE_SIZE) * TILE_SIZE,
                TILE_SIZE,
                TILE_SIZE,
            }
            if is_valid_pos && tower_budget > 0 {
                rl.DrawRectangleRec(highlight_rec, { 0, 228, 48, 100 })
                rl.DrawCircleV(tower_pos, SIGHT_RADIUS, { 0, 228, 48, 60 })
            } else {
                rl.DrawRectangleRec(highlight_rec, { 255, 0, 0, 100 })
            }

            for tower in towers {
                rl.DrawTextureV(tower_texture, tower.position - { TOWER_RADIUS, TOWER_RADIUS }, rl.WHITE)
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

            level_text := fmt.ctprintf("Level %v", current_level_index + 1)
            rl.DrawText(level_text, SCREEN_SIZE - 42, 7, 10, rl.GREEN)

            tower_budget_text := fmt.ctprintf("Tower Budget: %v", tower_budget)
            rl.DrawText(tower_budget_text, 5, 7, 10, rl.GREEN)

            if !started {
                start_text := fmt.ctprint("Start Level: SPACE")
                start_text_width := rl.MeasureText(start_text, 15)
                rl.DrawText(start_text, SCREEN_SIZE / 2 - start_text_width / 2, SCREEN_SIZE / 2 - 15 , 15, rl.RED)
            }
        } else {
            if !started {
                finish_text := fmt.ctprint("Thanks for all the Glazing!")
                finish_text_width := rl.MeasureText(finish_text, 15)
                rl.DrawText(finish_text, SCREEN_SIZE / 2 - finish_text_width / 2, SCREEN_SIZE / 2 - 15 , 15, rl.RED)

                restart_text := fmt.ctprint("New Game: R")
                restart_text_width := rl.MeasureText(restart_text, 10)
                rl.DrawText(restart_text, SCREEN_SIZE / 2 - restart_text_width / 2, SCREEN_SIZE / 2 + 5 , 10, rl.RED)
            }
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

    rl.CloseWindow()
}