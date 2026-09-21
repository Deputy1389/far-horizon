#include "FHPlayerCharacter.h"

#include "FHBlasterComponent.h"
#include "FHHealthComponent.h"
#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/SceneComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "InputAction.h"
#include "InputMappingContext.h"
#include "InputModifiers.h"
#include "InputCoreTypes.h"
#include "Math/RotationMatrix.h"

AFHPlayerCharacter::AFHPlayerCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    FirstPersonCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FirstPersonCamera"));
    FirstPersonCamera->SetupAttachment(GetCapsuleComponent());
    FirstPersonCamera->SetRelativeLocation(FVector(0.0, 0.0, 64.0));
    FirstPersonCamera->bUsePawnControlRotation = true;
    FirstPersonCamera->SetFieldOfView(HipFov);

    FirstPersonArms = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("FirstPersonArms"));
    FirstPersonArms->SetupAttachment(FirstPersonCamera);
    FirstPersonArms->SetOnlyOwnerSee(true);
    FirstPersonArms->SetCastShadow(false);
    FirstPersonArms->bCastDynamicShadow = false;
    FirstPersonArms->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    WeaponRoot = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponRoot"));
    WeaponRoot->SetupAttachment(FirstPersonCamera);
    WeaponRoot->SetRelativeLocation(FVector(35.0, 12.0, -12.0));

    WeaponMuzzle = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponMuzzle"));
    WeaponMuzzle->SetupAttachment(WeaponRoot);
    WeaponMuzzle->SetRelativeLocation(FVector(55.0, 0.0, 0.0));

    Blaster = CreateDefaultSubobject<UFHBlasterComponent>(TEXT("Blaster"));
    Health = CreateDefaultSubobject<UFHHealthComponent>(TEXT("Health"));

    bUseControllerRotationPitch = false;
    bUseControllerRotationYaw = true;
    bUseControllerRotationRoll = false;

    GetMesh()->SetOwnerNoSee(true);

    UCharacterMovementComponent* Movement = GetCharacterMovement();
    Movement->bOrientRotationToMovement = false;
    Movement->MaxWalkSpeed = WalkSpeed;
    Movement->BrakingDecelerationWalking = 1800.0f;
    Movement->GroundFriction = 8.0f;
    Movement->GetNavAgentPropertiesRef().bCanCrouch = true;
}

void AFHPlayerCharacter::BeginPlay()
{
    Super::BeginPlay();

    if (Health)
    {
        Health->OnDeath.AddDynamic(this, &AFHPlayerCharacter::HandleDeath);
    }
}

void AFHPlayerCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (FirstPersonCamera)
    {
        const float DesiredFov = bIsAiming ? AimFov : HipFov;
        const float NewFov = FMath::FInterpTo(
            FirstPersonCamera->FieldOfView,
            DesiredFov,
            DeltaSeconds,
            AimFovInterpSpeed);
        FirstPersonCamera->SetFieldOfView(NewFov);
    }
}

void AFHPlayerCharacter::PawnClientRestart()
{
    Super::PawnClientRestart();

    EnsureRuntimeInputObjects();

    APlayerController* PlayerController = Cast<APlayerController>(Controller);
    if (!PlayerController || !PlayerController->GetLocalPlayer())
    {
        return;
    }

    if (UEnhancedInputLocalPlayerSubsystem* InputSubsystem =
        ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PlayerController->GetLocalPlayer()))
    {
        InputSubsystem->RemoveMappingContext(DefaultInputContext);
        InputSubsystem->AddMappingContext(DefaultInputContext, 0);
    }
}

void AFHPlayerCharacter::EnsureRuntimeInputObjects()
{
    if (DefaultInputContext)
    {
        return;
    }

    DefaultInputContext = NewObject<UInputMappingContext>(this, TEXT("IMC_FarHorizon_Player"));

    MoveAction = NewObject<UInputAction>(this, TEXT("IA_Move"));
    MoveAction->ValueType = EInputActionValueType::Axis2D;
    MoveAction->AccumulationBehavior = EInputActionAccumulationBehavior::Cumulative;

    LookAction = NewObject<UInputAction>(this, TEXT("IA_Look"));
    LookAction->ValueType = EInputActionValueType::Axis2D;

    JumpAction = NewObject<UInputAction>(this, TEXT("IA_Jump"));
    JumpAction->ValueType = EInputActionValueType::Boolean;

    SprintAction = NewObject<UInputAction>(this, TEXT("IA_Sprint"));
    SprintAction->ValueType = EInputActionValueType::Boolean;

    CrouchAction = NewObject<UInputAction>(this, TEXT("IA_Crouch"));
    CrouchAction->ValueType = EInputActionValueType::Boolean;

    AimAction = NewObject<UInputAction>(this, TEXT("IA_Aim"));
    AimAction->ValueType = EInputActionValueType::Boolean;

    FireAction = NewObject<UInputAction>(this, TEXT("IA_Fire"));
    FireAction->ValueType = EInputActionValueType::Boolean;

    auto AddNegateX = [this](FEnhancedActionKeyMapping& Mapping)
    {
        UInputModifierNegate* Negate = NewObject<UInputModifierNegate>(DefaultInputContext);
        Negate->bX = true;
        Negate->bY = false;
        Negate->bZ = false;
        Mapping.Modifiers.Add(Negate);
    };

    auto AddSwizzleToY = [this](FEnhancedActionKeyMapping& Mapping)
    {
        UInputModifierSwizzleAxis* Swizzle = NewObject<UInputModifierSwizzleAxis>(DefaultInputContext);
        Swizzle->Order = EInputAxisSwizzle::YXZ;
        Mapping.Modifiers.Add(Swizzle);
    };

    FEnhancedActionKeyMapping& Forward = DefaultInputContext->MapKey(MoveAction, EKeys::W);
    AddSwizzleToY(Forward);

    FEnhancedActionKeyMapping& Backward = DefaultInputContext->MapKey(MoveAction, EKeys::S);
    AddNegateX(Backward);
    AddSwizzleToY(Backward);

    DefaultInputContext->MapKey(MoveAction, EKeys::D);

    FEnhancedActionKeyMapping& Left = DefaultInputContext->MapKey(MoveAction, EKeys::A);
    AddNegateX(Left);

    DefaultInputContext->MapKey(MoveAction, EKeys::Gamepad_Left2D);
    DefaultInputContext->MapKey(LookAction, EKeys::Mouse2D);
    DefaultInputContext->MapKey(LookAction, EKeys::Gamepad_Right2D);

    DefaultInputContext->MapKey(JumpAction, EKeys::SpaceBar);
    DefaultInputContext->MapKey(SprintAction, EKeys::LeftShift);
    DefaultInputContext->MapKey(CrouchAction, EKeys::LeftControl);
    DefaultInputContext->MapKey(AimAction, EKeys::RightMouseButton);
    DefaultInputContext->MapKey(FireAction, EKeys::LeftMouseButton);
}

void AFHPlayerCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);
    EnsureRuntimeInputObjects();

    UEnhancedInputComponent* EnhancedInput = Cast<UEnhancedInputComponent>(PlayerInputComponent);
    if (!EnhancedInput)
    {
        UE_LOG(LogTemp, Error, TEXT("Far Horizon requires UEnhancedInputComponent."));
        return;
    }

    EnhancedInput->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AFHPlayerCharacter::Move);
    EnhancedInput->BindAction(LookAction, ETriggerEvent::Triggered, this, &AFHPlayerCharacter::Look);

    EnhancedInput->BindAction(JumpAction, ETriggerEvent::Started, this, &AFHPlayerCharacter::StartJump);
    EnhancedInput->BindAction(JumpAction, ETriggerEvent::Completed, this, &AFHPlayerCharacter::StopJump);

    EnhancedInput->BindAction(SprintAction, ETriggerEvent::Started, this, &AFHPlayerCharacter::StartSprint);
    EnhancedInput->BindAction(SprintAction, ETriggerEvent::Completed, this, &AFHPlayerCharacter::StopSprint);

    EnhancedInput->BindAction(CrouchAction, ETriggerEvent::Started, this, &AFHPlayerCharacter::ToggleCrouch);
    EnhancedInput->BindAction(AimAction, ETriggerEvent::Started, this, &AFHPlayerCharacter::StartAim);
    EnhancedInput->BindAction(AimAction, ETriggerEvent::Completed, this, &AFHPlayerCharacter::StopAim);
    EnhancedInput->BindAction(FireAction, ETriggerEvent::Triggered, this, &AFHPlayerCharacter::Fire);
}

void AFHPlayerCharacter::Move(const FInputActionValue& Value)
{
    if (!Controller)
    {
        return;
    }

    const FVector2D Movement = Value.Get<FVector2D>();
    const FRotator ControlRotation = Controller->GetControlRotation();
    const FRotator YawRotation(0.0f, ControlRotation.Yaw, 0.0f);

    const FVector Forward = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::X);
    const FVector Right = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::Y);

    AddMovementInput(Forward, Movement.Y);
    AddMovementInput(Right, Movement.X);
}

void AFHPlayerCharacter::Look(const FInputActionValue& Value)
{
    const FVector2D LookInput = Value.Get<FVector2D>();
    AddControllerYawInput(LookInput.X * LookSensitivity);
    AddControllerPitchInput(-LookInput.Y * LookSensitivity);
}

void AFHPlayerCharacter::StartJump()
{
    Jump();
}

void AFHPlayerCharacter::StopJump()
{
    StopJumping();
}

void AFHPlayerCharacter::StartSprint()
{
    bIsSprinting = true;
    GetCharacterMovement()->MaxWalkSpeed = SprintSpeed;
}

void AFHPlayerCharacter::StopSprint()
{
    bIsSprinting = false;
    GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
}

void AFHPlayerCharacter::ToggleCrouch()
{
    if (bIsCrouched)
    {
        UnCrouch();
        return;
    }

    StopSprint();
    Crouch();
}

void AFHPlayerCharacter::StartAim()
{
    bIsAiming = true;
}

void AFHPlayerCharacter::StopAim()
{
    bIsAiming = false;
}

void AFHPlayerCharacter::Fire()
{
    if (!FirstPersonCamera || !WeaponMuzzle || !Blaster)
    {
        return;
    }

    Blaster->TryFire(
        FirstPersonCamera->GetComponentLocation(),
        FirstPersonCamera->GetForwardVector(),
        WeaponMuzzle->GetComponentLocation(),
        Controller);
}

void AFHPlayerCharacter::HandleDeath(AActor* DeadActor)
{
    StopSprint();
    bIsAiming = false;
    GetCharacterMovement()->DisableMovement();

    if (APlayerController* PlayerController = Cast<APlayerController>(Controller))
    {
        DisableInput(PlayerController);
    }
}
