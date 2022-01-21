# Before Altering

*Please read [Breaking into pieces](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md) first.*

*Disclamer: Information that is given here is only theoretical knowledge and the real experience might be different. The Author cannot be held responsible for any adverse effects.*

## Login manager & Greeter

- Add your Greeter to `GREETER` or `GREETER_AUR` variables and do your configurations in [Login manager](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#login-manager).

- Configure your [Background management](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#arrange-backgrounds).

## Boot loader

See:

- [Uefi check & Grub arguments](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#uefi-check--grub-arguments)

- [Boot loader](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#boot-loader)

- [Partition management](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#partitioning#partition-management)

## Kernel

- If you don't plan to use `systemd`, handle your `Service activation` in [post install services](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#services-1).

- Configure your `GRUB` accordingly (see: [Login manager](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#login-manager) and [Uefi check & Grub-arguments](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#uefi-check--grub-arguments))

- Check [```pkg_specific_operations()```](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md#pkg_specific_operations) and add your package dependent changes here.
