module.exports = {
    config: {
        colors: {
            black: '#000000',
            red: '#FF3B30',
            green: '#4CD964',
            yellow: '#FFCC00',
            blue: '#0095FF',
            magenta: '#FF2D55',
            cyan: '#5AC8FA',
            white: '#C7C7C7',
            lightBlack: '#686868',
            lightRed: '#FD6F6B',
            lightGreen: '#67F86F',
            lightYellow: '#FFFA72',
            lightBlue: '#6A76FB',
            lightMagenta: '#FD7CFC',
            lightCyan: '#68FDFE',
            lightWhite: '#FFFFFF',
        },

        // shell: 'zsh',
        // shellArgs: ['--login'],

        backgroundColor: 'rgba(0,0,0)',
        bell: false,
        borderColor: 'rgba(0,0,0,.15)',
        copyOnSelect: true,
        css: '',
        cursorAccentColor: 'rgba(248,28,229,0.8)',
        cursorBlink: true,
        cursorColor: '#0095FF',
        cursorShape: 'BEAM',
        defaultSSHApp: true,
        env: {
            'ZSH_INIT_COMMAND': 'mux start shell'
        },
        fontFamily: 'Hack Nerd Font',
        fontSize: 13,
        fontWeight: 'normal',
        fontWeightBold: 'bold',
        foregroundColor: '#fff',
        letterSpacing: 0,
        lineHeight: 1,
        macOptionSelectionMode: 'vertical',
        modifierKeys: {
            altIsMeta: true
        },
        padding: '12px 14px',
        quickEdit: false,
        selectionColor: '#0095FF',
        showHamburgerMenu: 'true',
        showWindowControls: '',
        termCSS: '',
        updateChannel: 'stable',
        webGLRenderer: true,

        hyperBorder: {
            animate: true,
            borderColors: ['#fc1da7', '#fba506'],
            borderWidth: '3px'
        },

        /// DEPRECATED
        hyperline: {
            plugins: [
                "hostname",
                "ip",
                "memory",
                "uptime",
                "cpu",
                "network",
                "battery",
                "time",
                "docker",
                "spotify",
            ]
        },

        /// TODO
        hyperTabsMove: {
            moveLeft: 'command+shift+left',
            moveRight: 'command+shift+right',
        },


        /// DEPRECATED
        StarWarsTheme: {
            character: 'emperor',
            lightsaber: 'true',
            unibody: 'false',
            avatar: 'true'
        },
        poketab: 'true',
        unibody: 'false'
    },

    plugins: [
        "git-falcon9",
        "hyper-broadcast",
        "hyper-custom-touchbar",
        "hyper-dracula",
        "hyper-pane",
        "hyper-search",
        "hyper-tabs-enhanced",
        "hyperalfred",
        "hyperborder",
        "hypercwd",
        "hyperminimal",
        "hyperpower",
        "hyperterm-tabs",

        /// DEPRECATED
        // "hyperline",
        // "hyper-opacity",
        // "hyper-star-wars",
        // "hyper-pokemon",
        // "verminal"
    ],

    localPlugins: [],

    keymaps: {},
};
