#include "FHHUD.h"

#include "Engine/Canvas.h"

void AFHHUD::DrawHUD()
{
    Super::DrawHUD();

    if (!Canvas)
    {
        return;
    }

    const FVector2D Center(
        Canvas->ClipX * 0.5f,
        Canvas->ClipY * 0.5f);

    const float Inner = CrosshairGap;
    const float Outer = CrosshairGap + CrosshairHalfSize;
    const FLinearColor Color = FLinearColor::White;

    DrawLine(
        Center.X - Outer,
        Center.Y,
        Center.X - Inner,
        Center.Y,
        Color,
        CrosshairThickness);

    DrawLine(
        Center.X + Inner,
        Center.Y,
        Center.X + Outer,
        Center.Y,
        Color,
        CrosshairThickness);

    DrawLine(
        Center.X,
        Center.Y - Outer,
        Center.X,
        Center.Y - Inner,
        Color,
        CrosshairThickness);

    DrawLine(
        Center.X,
        Center.Y + Inner,
        Center.X,
        Center.Y + Outer,
        Color,
        CrosshairThickness);
}
