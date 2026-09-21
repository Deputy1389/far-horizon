#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "FHGameMode.generated.h"

class APlayerStart;

UCLASS()
class FARHORIZON_API AFHGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    AFHGameMode();

    virtual void InitGame(
        const FString& MapName,
        const FString& Options,
        FString& ErrorMessage) override;

    virtual void BeginPlay() override;

    virtual AActor* ChoosePlayerStart_Implementation(
        AController* Player) override;

    UFUNCTION(BlueprintPure, Category="Far Horizon|Foundation")
    bool IsUsingEpicShooterFoundation() const
    {
        return bUsingEpicShooterFoundation;
    }

private:
    bool TryEnableEpicShooterFoundation();

    UPROPERTY(Transient)
    TObjectPtr<APlayerStart> RuntimePlayerStart;

    bool bUsingEpicShooterFoundation = false;
};
