#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "FHPlanetMath.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FFHPlanetRadialUpTest,
    "FarHorizon.Planet.RadialUp",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FFHPlanetRadialUpTest::RunTest(const FString& Parameters)
{
    const FVector Up = UFHPlanetMath::RadialUp(FVector(0.0, 0.0, 2000.0), FVector::ZeroVector);

    TestTrue(
        TEXT("Radial up should point away from the planet center."),
        Up.Equals(FVector::UpVector, KINDA_SMALL_NUMBER));

    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FFHPlanetAltitudeTest,
    "FarHorizon.Planet.AltitudeAboveSphere",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FFHPlanetAltitudeTest::RunTest(const FString& Parameters)
{
    const double Altitude = UFHPlanetMath::AltitudeAboveSphere(
        FVector(0.0, 0.0, 1500.0),
        FVector::ZeroVector,
        1000.0);

    TestEqual(
        TEXT("Altitude should be radial distance minus planet radius."),
        Altitude,
        500.0);

    return true;
}

#endif
