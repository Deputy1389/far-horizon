#include "FHEnemyCharacter.h"

#include "FHBlasterComponent.h"
#include "FHEnemyAIController.h"
#include "FHHealthComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

AFHEnemyCharacter::AFHEnemyCharacter()
{
    PrimaryActorTick.bCanEverTick = false;

    AIControllerClass = AFHEnemyAIController::StaticClass();
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

    UStaticMesh* Cube = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cube.Cube"));
    UStaticMesh* Sphere = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Sphere.Sphere"));
    UStaticMesh* Cylinder = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));

    auto AddBodyPart = [this](
        const TCHAR* Name,
        UStaticMesh* MeshAsset,
        const FVector& Location,
        const FVector& Scale,
        const FRotator& Rotation = FRotator::ZeroRotator)
    {
        if (!MeshAsset)
        {
            return;
        }

        UStaticMeshComponent* Part =
            CreateDefaultSubobject<UStaticMeshComponent>(Name);
        Part->SetupAttachment(GetRootComponent());
        Part->SetStaticMesh(MeshAsset);
        Part->SetRelativeLocation(Location);
        Part->SetRelativeScale3D(Scale);
        Part->SetRelativeRotation(Rotation);
        Part->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Part->SetCastShadow(true);
    };

    AddBodyPart(
        TEXT("ProxyTorso"),
        Cube,
        FVector(0.0, 0.0, 18.0),
        FVector(0.32, 0.22, 0.48));

    AddBodyPart(
        TEXT("ProxyHead"),
        Sphere,
        FVector(0.0, 0.0, 78.0),
        FVector(0.20));

    AddBodyPart(
        TEXT("ProxyLeftLeg"),
        Cube,
        FVector(-5.0, -12.0, -45.0),
        FVector(0.10, 0.10, 0.42));

    AddBodyPart(
        TEXT("ProxyRightLeg"),
        Cube,
        FVector(-5.0, 12.0, -45.0),
        FVector(0.10, 0.10, 0.42));

    AddBodyPart(
        TEXT("ProxyRifle"),
        Cylinder,
        FVector(35.0, 24.0, 25.0),
        FVector(0.045, 0.045, 0.42),
        FRotator(0.0, 90.0, 0.0));

    UPointLightComponent* CombatMarker =
        CreateDefaultSubobject<UPointLightComponent>(TEXT("CombatMarker"));
    CombatMarker->SetupAttachment(GetRootComponent());
    CombatMarker->SetRelativeLocation(FVector(0.0, 0.0, 95.0));
    CombatMarker->SetLightColor(FLinearColor(1.0f, 0.05f, 0.02f));
    CombatMarker->SetIntensity(900.0f);
    CombatMarker->SetAttenuationRadius(220.0f);
    CombatMarker->SetCastShadows(false);

    WeaponMuzzle = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponMuzzle"));
    WeaponMuzzle->SetupAttachment(GetRootComponent());
    WeaponMuzzle->SetRelativeLocation(FVector(80.0, 24.0, 25.0));

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
