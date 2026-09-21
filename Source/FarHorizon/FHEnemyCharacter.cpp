#include "FHEnemyCharacter.h"

#include "FHBlasterComponent.h"
#include "FHEnemyAIController.h"
#include "FHHealthComponent.h"
#include "Components/SceneComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

AFHEnemyCharacter::AFHEnemyCharacter()
{
    PrimaryActorTick.bCanEverTick = false;

    AIControllerClass = AFHEnemyAIController::StaticClass();
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

    WeaponMuzzle = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponMuzzle"));
    WeaponMuzzle->SetupAttachment(GetRootComponent());
    WeaponMuzzle->SetRelativeLocation(FVector(45.0, 15.0, 55.0));

    Blaster = CreateDefaultSubobject<UFHBlasterComponent>(TEXT("Blaster"));
    Health = CreateDefaultSubobject<UFHHealthComponent>(TEXT("Health"));

    GetCharacterMovement()->MaxWalkSpeed = 420.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    bUseControllerRotationYaw = false;
}

void AFHEnemyCharacter::BeginPlay()
{
    Super::BeginPlay();

    if (Health)
    {
        Health->OnDeath.AddDynamic(this, &AFHEnemyCharacter::HandleDeath);
    }
}

bool AFHEnemyCharacter::TryFireAt(AActor* Target)
{
    if (!Target || !Blaster || !WeaponMuzzle)
    {
        return false;
    }

    const FVector ViewLocation = GetPawnViewLocation();
    const FVector TargetPoint = Target->GetActorLocation() + FVector(0.0, 0.0, 55.0);
    const FVector ViewDirection = (TargetPoint - ViewLocation).GetSafeNormal();

    return Blaster->TryFire(
        ViewLocation,
        ViewDirection,
        WeaponMuzzle->GetComponentLocation(),
        GetController());
}

void AFHEnemyCharacter::HandleDeath(AActor* DeadActor)
{
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false);
    SetLifeSpan(2.0f);
}
