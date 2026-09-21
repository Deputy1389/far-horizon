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

    virtual void BeginPlay() override;

    virtual AActor* ChoosePlayerStart_Implementation(
        AController* Player) override;

private:
    UPROPERTY(Transient)
    TObjectPtr<APlayerStart> RuntimePlayerStart;
};
