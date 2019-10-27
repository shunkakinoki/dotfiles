module.exports = {
    config: {
        updateChannel: 'stable',
        fontSize: 14,
        fontFamily: 'Hack Nerd Font',
        fontWeight: 'normal',
        fontWeightBold: 'bold',
        lineHeight: 1,
        letterSpacing: 0,
        cursorColor: '#0095FF',
        cursorAccentColor: 'rgba(248,28,229,0.8)',
        cursorShape: 'BEAM',
        cursorBlink: true,
        foregroundColor: '#fff',
        backgroundColor: 'rgba(0,0,0)',
        selectionColor: 'rgba(248,28,229,0.3)',
        borderColor: 'rgba(0,0,0,.15)',
        css: '',
        termCSS: '',
        bell: false,
        showHamburgerMenu: 'true',
        showWindowControls: '',
        padding: '12px 14px',
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
        env: {},
        copyOnSelect: true,
        defaultSSHApp: true,
        quickEdit: false,
        macOptionSelectionMode: 'vertical',
        webGLRenderer: true,

        hyperBorder: {
            animate: true,
            borderColors: ['#fc1da7', '#fba506'],
            borderWidth: '3px'
        },

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
        "hyperalfred",
        "hyperborder",
        "hypercwd",
        "hyperline",
        "hyperpower",
        "hyperterm-tabs",
        "hyper-broadcast",
        "hyper-custom-touchbar",
        "hyper-pane",
        "hyper-search",
        "hyper-tabs-enhanced",

        /// DEPRECATED
        // "hyper-opacity",
        //  "hyper-star-wars",
        // "hyper-pokemon",
        // "verminal"
    ],

    localPlugins: [],

    keymaps: {},
};
