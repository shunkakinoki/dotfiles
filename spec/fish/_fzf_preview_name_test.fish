set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fzf_preview_name.fish

@test "with arg includes arg name" (string match -q "*Files*" (_fzf_preview_name "Files"); echo $status) = 0
@test "no arg shows Search" (string match -q "*Search*" (_fzf_preview_name); echo $status) = 0
@test "with arg includes prompt arrow" (string match -q "*Files*" (_fzf_preview_name "Files"); echo $status) = 0
