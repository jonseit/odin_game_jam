package game

import rl "vendor:raylib"

restart :: proc() {

}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(1000, 1000, "Odin Game Jam")
    rl.InitAudioDevice()
    rl.SetTargetFPS(500)

    restart()

    for !rl.WindowShouldClose() {

        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLUE)

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}