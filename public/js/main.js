// Copy to clipboard functionality
function copyToClipboard(button) {
    const codeBlock = button.parentElement.querySelector('code');
    const text = codeBlock.textContent;

    navigator.clipboard.writeText(text).then(() => {
        // Visual feedback
        button.classList.add('copied');
        button.textContent = 'Copied';

        // Reset after 2 seconds
        setTimeout(() => {
            button.classList.remove('copied');
            button.textContent = 'Copy';
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy text: ', err);
        button.textContent = 'Failed';
        setTimeout(() => {
            button.textContent = 'Copy';
        }, 2000);
    });
}

// OS selector functionality (for legacy use cases)
function selectOS(os) {
    // Remove active class from all tabs and commands
    document.querySelectorAll('.os-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('.os-command').forEach(cmd => {
        cmd.classList.remove('active');
    });

    // Add active class to selected tab and command
    event.target.classList.add('active');
    document.getElementById('cmd-' + os).classList.add('active');
}

// Organization method selector
function selectOrgMethod(method) {
    // Remove active class from all tabs and commands
    document.querySelectorAll('.os-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('.os-command').forEach(cmd => {
        cmd.classList.remove('active');
    });

    // Add active class to selected tab and command
    event.target.classList.add('active');
    document.getElementById('org-' + method).classList.add('active');
}

// Install method selector
function selectInstallMethod(method) {
    // Only affect the top-level install method tabs and panels
    const quickstartSection = document.getElementById('quickstart');

    // Get the direct os-selector (first one in quickstart)
    const topSelector = quickstartSection.querySelector(':scope > .os-selector');
    topSelector.querySelectorAll('.os-tab').forEach(tab => {
        tab.classList.remove('active');
    });

    // Hide both install method panels
    document.getElementById('install-installer').classList.remove('active');
    document.getElementById('install-source').classList.remove('active');

    // Add active class to selected tab and command
    event.target.classList.add('active');
    document.getElementById('install-' + method).classList.add('active');
}

// Installer OS selector
function selectInstallerOS(os) {
    // Remove active class from installer OS tabs and commands
    document.querySelectorAll('#install-installer .os-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('#install-installer .os-command').forEach(cmd => {
        cmd.classList.remove('active');
    });

    // Add active class to selected tab and command
    event.target.classList.add('active');
    document.getElementById('installer-cmd-' + os).classList.add('active');
}

// Source build OS selector
function selectSourceOS(os) {
    // Remove active class from source OS tabs and commands
    document.querySelectorAll('#install-source .os-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('#install-source .os-command').forEach(cmd => {
        cmd.classList.remove('active');
    });

    // Add active class to selected tab and command
    event.target.classList.add('active');
    document.getElementById('source-cmd-' + os).classList.add('active');
}