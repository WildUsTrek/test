# PERLA1 Runtime Module Staging

This directory is a staging area for controlled modularization. 

`index.html` remains the playable runtime source of truth. Files here must not be loaded by the game until a specific extraction has a scoped plan, static CI proof, and runtime validation proof.

Use `module-boundaries.json` to track candidate module ownership before moving code.
