#include "FHGameMode.h"

#include "FHFoundationArena.h"
#include "FHFrontierWorld.h"
#include "FHHUD.h"
#include "FHPlayerCharacter.h"
#include "Engine/World.h"
#include "GameFramework/PlayerStart.h"
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

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    if (FParse::Param(FCommandLine::Get(), TEXT("FoundationArena")))
    {
        GetWorld()->SpawnActor<AFHFoundationArena>(
            FVector::ZeroVector,
            FRotator::ZeroRotator,
            Params);
        return;
    }

    GetWorld()->SpawnActor<AFHFrontierWorld>(
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

    UWorld* World = GetWorld();
    if (!World)
    {
        return nullptr;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    RuntimePlayerStart = World->SpawnActor<APlayerStart>(
        FVector(-118000.0f, -88000.0f, 180.0f),
        FRotator(0.0f, 38.0f, 0.0f),
        Params);

    return RuntimePlayerStart;
}
