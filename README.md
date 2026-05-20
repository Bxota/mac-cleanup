# mac-cleanup

Nettoyage automatique hebdomadaire pour macOS : caches Homebrew/Go/pip/Docker, `node_modules` et dossiers `target/` inactifs depuis 30 jours.

## Installation via Homebrew

```bash
brew tap Bxota/mac-cleanup https://github.com/Bxota/mac-cleanup
brew install mac-cleanup
brew services start mac-cleanup
```

Le LaunchAgent se lance automatiquement chaque samedi à 10h00.

## Utilisation manuelle

```bash
# Lancement immédiat
mac-cleanup

# Simulation sans suppression
mac-cleanup --dry-run
```

## Logs

```bash
ls ~/.local/share/mac-cleanup/
```

## Désinstallation

```bash
brew services stop mac-cleanup
brew uninstall mac-cleanup
brew untap Bxota/mac-cleanup
```

## Ce qui est nettoyé

| Cible | Condition |
|---|---|
| Chrome OptGuideOnDeviceModel | Toujours |
| Claude vm_bundles + Cache | Toujours |
| Homebrew (`brew cleanup --prune=all`) | Toujours |
| Go build cache | Si `go` installé |
| pip cache | Si `pip3` installé |
| Docker prune | Si Docker actif |
| `node_modules/` | Projet inactif >30j |
| Rust `target/` | Projet inactif >30j |
