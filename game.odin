package game

import rl "vendor:raylib"

SCREEN_WIDTH_PX :: 1000
SCREEN_HEIGHT_PX :: 1000
NUM_TILES_PER_SIDE :: 20
TILE_LENGTH :: 50
TRACK_LENGTH :: 33

Enemy :: struct {
    position: rl.Vector2
}

Tower :: struct {
    position: rl.Vector2
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

enemies: [dynamic]Enemy
towers: [dynamic]Tower

restart :: proc() {

}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_WIDTH_PX, SCREEN_HEIGHT_PX, "Odin Game Jam")
    rl.InitAudioDevice()
    rl.SetTargetFPS(500)

    restart()

    for !rl.WindowShouldClose() {

        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLUE)

        for tile in track_tiles {
            tile_rec := rl.Rectangle {
                tile.x * TILE_LENGTH,
                tile.y * TILE_LENGTH,
                TILE_LENGTH,
                TILE_LENGTH,
            }

            rl.DrawRectangleRec(tile_rec, rl.BROWN)
        }

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}