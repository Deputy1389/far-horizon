#include "FHEnemyCharacter.h"

#include "FHBlasterComponent.h"
#include "FHEnemyAIController.h"
#include "FHHealthComponent.h"
#include "Animation/AnimationAsset.h"
#include "Animation/AnimSequence.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/SceneComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/CharacterMovementComponent.h"

AFHEnemyCharacter::AFHEnemyCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    AIControllerClass = AFHEnemyAIController::StaticClass();
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

    USkeletalMesh* LocalStormtrooper = LoadObject<USkeletalMesh>(
        nullptr,
        TEXT("/Game/FarHorizon/LocalSWG/Models/SK_SWG_Stormtrooper.SK_SWG_Stormtrooper"));

    if (LocalStormtrooper)
    {
        bUsingLocalSwgPresentation = true;

        GetMesh()->SetSkeletalMesh(LocalStormtrooper);
        GetMesh()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        GetMesh()->SetCastShadow(true);

        const FBoxSphereBounds Bounds = LocalStormtrooper->GetBounds();
        const float RawHeight = FMath::Max(1.0f, Bounds.BoxExtent.Z * 2.0f);
        const float UniformScale = 182.0f / RawHeight;
        const float ScaledMinZ =
            (Bounds.Origin.Z - Bounds.BoxExtent.Z) * UniformScale;

        GetMesh()->SetRelativeScale3D(FVector(UniformScale));
        GetMesh()->SetRelativeLocation(
            FVector(
                -Bounds.Origin.X * UniformScale,
                -Bounds.Origin.Y * UniformScale,
                -GetCapsuleComponent()->GetScaledCapsuleHalfHeight() - ScaledMinZ));
        GetMesh()->SetRelativeRotation(FRotator(0.0f, -90.0f, 0.0f));

        IdleAnimation = LoadObject<UAnimSequence>(
            nullptr,
            TEXT("/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_Idle.A_SWG_Stormtrooper_Idle"));

        WalkAnimation = LoadObject<UAnimSequence>(
            nullptr,
            TEXT("/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_WalkForward.A_SWG_Stormtrooper_WalkForward"));

        RunAnimation = LoadObject<UAnimSequence>(
            nullptr,
            TEXT("/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_RunForward.A_SWG_Stormtrooper_RunForward"));

        FireAnimation = LoadObject<UAnimSequence>(
            nullptr,
            TEXT("/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_Fire.A_SWG_Stormtrooper_Fire"));

        if (IdleAnimation)
        {
            GetMesh()->SetAnimationMode(EAnimationMode::AnimationSingleNode);
            GetMesh()->PlayAnimation(IdleAnimation, true);
            CurrentPresentationAnimation = IdleAnimation;
        }
    }
    else
    {
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
    }

    UPointLightComponent* CombatMarker =
        CreateDefaultSubobject<UPointLightComponent>(TEXT("CombatMarker"));
    CombatMarker->SetupAttachment(GetRootComponent());
    CombatMarker->SetRelativeLocation(FVector(0.0, 0.0, 105.0));
    CombatMarker->SetLightColor(FLinearColor(1.0f, 0.05f, 0.02f));
    CombatMarker->SetIntensity(480.0f);
    CombatMarker->SetAttenuationRadius(160.0f);
    CombatMarker->SetCastShadows(false);

    WeaponMuzzle = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponMuzzle"));
    WeaponMuzzle->SetupAttachment(GetRootComponent());
    WeaponMuzzle->SetRelativeLocation(FVector(85.0, 24.0, 35.0));

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

void AFHEnemyCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    UpdatePresentationAnimation(DeltaSeconds);
}

void AFHEnemyCharacter::UpdatePresentationAnimation(float DeltaSeconds)
{
    if (!bUsingLocalSwgPresentation || !GetMesh())
    {
        return;
    }

    if (FirePresentationRemaining > 0.0f)
    {
        FirePresentationRemaining =
            FMath::Max(0.0f, FirePresentationRemaining - DeltaSeconds);

        if (FirePresentationRemaining > 0.0f)
        {
            return;
        }
    }

    const float Speed = GetVelocity().Size2D();

    UAnimationAsset* Desired = IdleAnimation;
    if (Speed > 520.0f && RunAnimation)
    {
        Desired = RunAnimation;
    }
    else if (Speed > 20.0f && WalkAnimation)
    {
        Desired = WalkAnimation;
    }

    if (Desired && Desired != CurrentPresentationAnimation)
    {
        GetMesh()->PlayAnimation(Desired, true);
        CurrentPresentationAnimation = Desired;
    }
}

bool AFHEnemyCharacter::TryFireAt(AActor* Target)
{
    if (!Target || !Blaster || !WeaponMuzzle)
    {
        return false;
    }

    const FVector ViewLocation = GetPawnViewLocation();
    const FVector TargetPoint =
        Target->GetActorLocation() + FVector(0.0, 0.0, 55.0);

    const FVector ViewDirection =
        (TargetPoint - ViewLocation).GetSafeNormal();

    const bool bFired = Blaster->TryFire(
        ViewLocation,
        ViewDirection,
        WeaponMuzzle->GetComponentLocation(),
        GetController());

    if (bFired && FireAnimation && bUsingLocalSwgPresentation)
    {
        GetMesh()->PlayAnimation(FireAnimation, false);
        CurrentPresentationAnimation = FireAnimation;
        FirePresentationRemaining = 0.28f;
    }

    return bFired;
}

void AFHEnemyCharacter::HandleDeath(AActor* DeadActor)
{
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false);
    SetLifeSpan(2.0f);
}
