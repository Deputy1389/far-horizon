#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "FHHUD.generated.h"

UCLASS()
class FARHORIZON_API AFHHUD : public AHUD
{
    GENERATED_BODY()

public:
    virtual void DrawHUD() override;

    UPROPERTY(EditDefaultsOnly, Category="HUD")
    float CrosshairHalfSize = 6.0f;

    UPROPERTY(EditDefaultsOnly, Category="HUD")
    float CrosshairGap = 4.0f;

    UPROPERTY(EditDefaultsOnly, Category="HUD")
    float CrosshairThickness = 1.5f;
};
