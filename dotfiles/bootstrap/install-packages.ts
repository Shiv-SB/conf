import { $ } from "bun";

$.nothrow();

console.log(":::: Running install-packages.ts ::::");

const COMMON_PACKAGES: string[] = [
    "btop",
    "micro",
    "zsh",
    "fastfetch",
    "stockfish",
];

const EXTRA_MAC_PACKAGES: string[] = [

];

const EXTRA_LINUX_PACKAGES: string[] = [

];

const OS = process.platform;

console.log("   Detected OS:", OS);

function spawn(cmd: string[]): void {
    console.log("   >>>> Running cmd:", cmd.join(" "));
    return;
    Bun.spawnSync(cmd, {
        stdout: "inherit",
        stderr: "inherit",
        stdin: "ignore",
    });
}

function checkForNVM(): boolean {
  const proc = Bun.spawnSync(["bash", "-c", `
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm --version
  `], { stdout: "ignore" });

  return proc.exitCode === 0;
}

async function doesExist(pkg: string): Promise<boolean> {
    try {
        if (pkg === "nvm") return checkForNVM();
        const code = (await $`command -v ${pkg}`.quiet()).exitCode;
        return code === 0;
    } catch (_err) {
        return false;
    }
}

if (OS === "win32") {
    console.error("Windows not supported!");
    process.exit(1);
}

if (OS === "darwin") {
    console.log("   Installing macOS specific packages...");
    const allPackages = EXTRA_MAC_PACKAGES
        .concat(COMMON_PACKAGES)
        .join(" ");
    spawn(["brew", "install", allPackages]);
} else {
    console.log("   Installing Linux/WSL specific packages...");
    const allPackages = EXTRA_LINUX_PACKAGES
        .concat(COMMON_PACKAGES)
        .join(" ");
    spawn(["sudo", "apt", "update"]);
    spawn(["apt", "install", "-y", allPackages]);
}

//#region Manual Installs

console.log("   Installing TypeScript globally...");
spawn(["bun", "i", "-g", "typescript"]);

if (!await doesExist("nvm")) {
    console.log("Installing NVM...");
    spawn(["curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"]);
    if (await doesExist("nvm")) {
        console.log("Installing latest Node via NVM...");
        spawn(["nvm", "install", "node"]);
        console.log("Run 'nvm use node' after restarting your shell.");
    }
} else {
    console.log("NVM already installed");
}

if (!await doesExist("cargo")) {
    console.log("Installing Rust/Cargo...");
    spawn(["curl https://sh.rustup.rs -sSf | sh -s -- -y"]);
} else {
    console.log("Rust/Cargo already installed");
}

if (!await doesExist("cargo") && !await doesExist("chess-tui")) {
    console.log("Installing chess-tui...");
    spawn(["cargo", "install", "chess-tui"]);
    if (await doesExist("chess-tui") && await doesExist("stockfish")) {
        console.log("Linking Stockfish to chess-tui...");
        if (OS === "darwin") {
            spawn(["chess-tui", "-e", "/opt/homebrew/opt/stockfish/bin"]);
        } else {
            // Need to find bin path for linux locations
            // I think its /usr/games/stockfish
            console.log("TODO: Link stockfish to chess-tui in Linux");
        }
    }
}

//#region ZSH Plugins

console.log("Installing ZSH Plugins...");
spawn([
    "git", 
    "clone", 
    "https://github.com/zsh-users/zsh-history-substring-search", 
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search"
]);

console.log("Attempting install of zsh-autosuggestions...");
spawn([
    "git",
    "clone",
    "https://github.com/zsh-users/zsh-autosuggestions.git",
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions",
]);

console.log("Attempting install of zsh-syntax-highlighting...");
spawn([
    "git",
    "clone",
    "https://github.com/zsh-users/zsh-syntax-highlighting.git",
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting",
]);

console.log("Attempting install of OMZ...");
spawn(["sh", "-c", '"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"']);

