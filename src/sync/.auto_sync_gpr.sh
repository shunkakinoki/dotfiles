cd ~/dotfiles
git master-cleanse
git aa
HUSKY_SKIP_HOOKS=1 git cm "perf(auto-update): auto-sync-gpr"
git checkout -b auto-sync-gpr
git publish && hub pull-request --no-edit
cd ~
