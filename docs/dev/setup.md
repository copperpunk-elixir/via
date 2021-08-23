# Development Environment Setup
We use Ubuntu 20.04 for most our development. However, we occasionally find ourselves on Macs or PCs, and that seems to work alright too. These instructions will not describe any of the pitfalls that might be seen while installing third-party software, as those issues will surely have their own solutions somewhere else on the web.

## Step 1: Install Elixir and Nerves
Please follow these instructions: https://hexdocs.pm/nerves/installation.html

## Step 2: Install Scenic Dependencies (for use with ground station)
NOTE: At some point we will transition to Phoenix LiveView for our ground station software so that it can be used on any machine with a browser. Until then we will be sticking with Scenic.<br>
Please follow these instructions: https://github.com/boydm/scenic/blob/master/guides/install_dependencies.md

## Step 3: Fork Via repository
All stable code lives on the `main` branch, and that is where we typically work. When we are developing large new features or performing significant refactors, we will create a single branch that will be deleted once its code is merged.
> There will be much more to come regarding collaboration strategies.

## Step 4: Ensure that the code compiles
In a terminal, navigate to the `via` directory and execute the following:
```
MIX_ENV=test iex -S mix
```
If you encounter any errors, please let us know and we will add them to the [Setup FAQ](faq.md).

## Step 5: Profit
If you figure this one out, you're way ahead of us.