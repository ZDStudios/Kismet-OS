# Tomorrow goal

## Primary target
Get Kismet OS to the point where the Ubuntu-based containerized build pipeline can successfully:
- fetch a valid base ISO
- extract it
- apply Kismet overlay changes
- repack the live filesystem
- move toward an actual preview image

## Current confidence
The environment/tooling problem has been solved. The current blocker is just the invalid cached base-image fetch, which is much more ordinary and fixable.
