#include "FHGameMode.h"
#include "FHPlayerCharacter.h"

AFHGameMode::AFHGameMode()
{
    DefaultPawnClass = AFHPlayerCharacter::StaticClass();
}
