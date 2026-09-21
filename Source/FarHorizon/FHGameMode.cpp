#include "FHGameMode.h"

#include "FHFoundationArena.h"
#include "FHHUD.h"
#include "FHPlayerCharacter.h"
#include "Engine/World.h"
#include "GameFramework/PlayerStart.h"
#include "HAL/IConsoleManager.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"

AFHGameMode::AFHGameMode()
{
    DefaultPawnClass = AFHPlayerCharacter::StaticClass();
    HUDClass = AFHHUD::StaticClass();
}

void AFHGameMode::BeginPlay()
{
    Super::BeginPlay();

    if (FParse::Param(FCommandLine::Get(), TEXT("NoFoundationArena")))
    {
        return;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    GetWorld()->SpawnActor<AFHFoundationArena>(
        FVector::ZeroVector,
        FRotator::ZeroRotator,
        Params);
}

AActor* AFHGameMode::ChoosePlayerStart_Implementation(
    AController* Player)
{
    if (RuntimePlayerStart)
    {
        return RuntimePlayerStart;
    }

    if (AActor* Existing = Super::ChoosePlayerStart_Implementation(Player))
    {
        return Existing;
    }

    UWorld* World = GetWorld();
    if (!World)
    {
        return nullptr;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    RuntimePlayerStart = World->SpawnActor<APlayerStart>(
        FVector(-1500.0, 0.0, 110.0),
        FRotator::ZeroRotator,
        Params);

    return RuntimePlayerStart;
}
