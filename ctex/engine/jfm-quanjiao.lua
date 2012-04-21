luatexja.jfont.define_jfm {
  dir = 'yoko',
  zw = 1.0, zh = 1.0,

  [0] = {
    align = 'left', left = 0.0, down = 0.0,
    width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
    glue = {
      [1] = { 0.5 , 0.0, 0.0  },
      [3] = { 0.25, 0.0, 0.25 }
    }
  },

  [1] = { -- fw. opening punctuations
    chars = {
      0x2018, 0x201C, 0x3008, 0x300A, 0x300C, 0x300E, 0x3010, 0x3014, 0x3016, 
      0x3018, 0x301D, 0xFF08, 0xFF3B, 0xFF5B, 0xFF5F
    },
    align = 'right', left = 0.0, down = 0.0,
    width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
    glue = {
      [3] = { 0.25, 0.0, 0.25 }
    }
  },

  [2] = { -- fw. closing/colon punctuations
    chars = {
      0x2019, 0x201D, 0x3001, 0x3009, 0x300B, 0x300D, 0x300F, 0x3011, 0x3015, 
      0x3017, 0x3019, 0x301F, 0xFF09, 0xFF0C, 0xFF3D, 0xFF5D, 0xFF60,
      0xFF1A, 0xFF1B  
    },
    align = 'left', left = 0.0, down = 0.0,
    width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
    glue = {
      [0] = { 0.5 , 0.0, 0.0 },
      [1] = { 0.25, 0.0, 0.0 },
      [3] = { 0.25, 0.0, 0.0 },
      [5] = { 0.25, 0.0, 0.0 }
    }
  },

  [3] = { -- fw. middle dot punctuations
    chars = {0x30FB, 0x00B7},
    align = 'middle', left = 0.0, down = 0.0,
    width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
    glue = {
      [0] = { 0.25, 0.0, 0.25 },
      [1] = { 0.25, 0.0, 0.25 },
      [2] = { 0.25, 0.0, 0.25 },
      [3] = { 0.5 , 0.0, 0.5  },
      [4] = { 0.25, 0.0, 0.25 },
      [5] = { 0.25, 0.0, 0.25 },
    }
  },

  [4] = { -- fw. stop punctuations
    chars = {0x3002, 0xFF01, 0xFF0E, 0xFF1F},
    align = 'left', left = 0.0, down = 0.0,
    width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
    glue = {
      [0] = { 0.5 , 0.0, 0.0 },
      [1] = { 0.5 , 0.0, 0.0 },
      [3] = { 0.5 , 0.0, 0.0 },
      [5] = { 0.5 , 0.0, 0.0 }
    }
  },

  [5] = { -- fw. dash punctuations
    chars = { 0x2015, 0x2025, 0x2026, 0x2014, 0x301C, 0xFF5E },
    align = 'middle', left = 0.0, down = 0.0,
    width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
    glue = {
      [1] = { 0.5 , 0.0, 0.5  },
      [3] = { 0.25, 0.0, 0.25 }
    },
    kern = {
      [5] = -0.1
    }
  },

  [6] = { -- box end
    chars = {'boxbdd'},
  },

}
