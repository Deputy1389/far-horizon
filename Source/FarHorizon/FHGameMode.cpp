#include "FHGameMode.h"

#include "FHFoundationArena.h"
#include "FHHUD.h"
#include "FHPlayerCharacter.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerStart.h"
#include "HAL/IConsoleManager.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "UObject/SoftObjectPath.h"

namespace
{
    static const TCHAR* ShooterCharacterClassPath =
        TEXT("/Game/Variant_Shooter/Blueprints/BP_ShooterCharacter.BP_ShooterCharacter_C");

    static const TCHAR* ShooterPlayerControllerClassPath =
        TEXT("/Game/Variant_Shooter/Blueprints/BP_ShooterPlayerController.BP_ShooterPlayerController_C");
}

AFHGameMode::AFHGameMode()
{
    DefaultPawnClass = AFHPlayerCharacter::StaticClass();
    HUDClass = AFHHUD::StaticClass();
}

void AFHGameMode::InitGame(
    const FString& MapName,
    const FString& Options,
    FString& ErrorMessage)
{
    TryEnableEpicShooterFoundation();
    Super::InitGame(MapName, Options, ErrorMessage);
}

bool AFHGameMode::TryEnableEpicShooterFoundation()
{
    if (FParse::Param(FCommandLine::Get(), TEXT("FarHorizonCppFPS")))
    {
        return false;
    }

    const FSoftClassPath CharacterPath(ShooterCharacterClassPath);
    const FSoftClassPath ControllerPath(ShooterPlayerControllerClassPath);

    UClass* ShooterCharacterClass =
        CharacterPath.TryLoadClass<APawn>();

    UClass* ShooterControllerClass =
        ControllerPath.TryLoadClass<APlayerController>();

    if (!ShooterCharacterClass || !ShooterControllerClass)
    {
        UE_LOG(
            LogTemp,
            Display,
            TEXT("Far Horizon: Epic Shooter foundation not installed locally; using C++ fallback FPS."));
        return false;
    }

    DefaultPawnClass = ShooterCharacterClass;
    PlayerControllerClass = ShooterControllerClass;
    bUsingEpicShooterFoundation = true;

    UE_LOG(
        LogTemp,
        Display,
        TEXT("Far Horizon: using migrated Epic UE 5.8 Shooter character/controller foundation."));

    return true;
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
