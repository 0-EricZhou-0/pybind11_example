# Check for Python package dependencies
# Usage: python3 py3_require_package.py "package_name[specifier]"
# Outputs: the installed version for the package if the requirement is met
# Returns: 0 if the requirement is met, non-zero otherwise

import importlib
from importlib.metadata import version, PackageNotFoundError
from packaging.requirements import Requirement
import sys, os

if "NO_COLOR" in os.environ and len(os.environ["NO_COLOR"]) != 0:
    RED = ""
    RESET = ""
else:
    RED = "\033[31m"
    RESET = "\033[0m"

assert len(sys.argv) >= 2, "Usage: python3 py3_require_package.py 'package_name[specifier]'"

req = Requirement(sys.argv[1])
version_check_bypass = False
try:
    installed_version = version(req.name)
except PackageNotFoundError:
    # is not a installed package
    try:
        module = importlib.import_module(req.name)
        # can be imported, but not an installed package
        if hasattr(module, '__version__'):
            # has a __version__ attribute
            installed_version = module.__version__
        elif len(req.specifier) > 0:
            # does not have a __version__ attribute, and version check is required
            print(
                f"{RED}[PyPkg Dependency Checker] Package {req.name} can be imported, "
                f"but cannot determine version from module while requirement {req.specifier} is specified.{RESET}",
                file=sys.stderr)
            sys.exit(1)
        else:
            # no __version__ attribute and no version check required
            installed_version = "unknown"
            version_check_bypass = True
    except ModuleNotFoundError:
        # cannot be imported
        print(
            f"{RED}[PyPkg Dependency Checker] Package {req.name} cannot be imported.{RESET}",
            file=sys.stderr)
        sys.exit(1)

# perform version check
retcode = 0
if not version_check_bypass and not req.specifier.contains(installed_version, prereleases=True):
    print(
        f"{RED}[PyPkg Dependency Checker] Package {req.name} is installed "
        f"(version {installed_version}) but does not satisfy the requirement: "
        f"{req.name}{req.specifier}{RESET}",
        file=sys.stderr)
    retcode = 1
print(installed_version)
sys.exit(retcode)
