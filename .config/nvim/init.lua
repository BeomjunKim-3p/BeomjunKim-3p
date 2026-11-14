-- 1. Lazy.nvim (플러그인 관리자) 자동 설치
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 스페이스바(" ")를 리더 키로 설정하겠다는 뜻
vim.g.mapleader = " "

vim.opt.termguicolors = true

vim.opt.number = true

vim.filetype.add({
  extension = {
    MD = 'markdown',
  },
})

-- 2. 플러그인 설정 시작
require("lazy").setup({
  -- LSP 관리자 (언어별 서버 설치를 쉽게 해줌)
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  { "neovim/nvim-lspconfig" },

  -- 자동완성 엔진 및 UI
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" }, -- LSP용 자동완성 소스
  { "hrsh7th/cmp-buffer" },   -- 현재 버퍼(텍스트)용 자동완성 소스
  { "hrsh7th/cmp-path" },     -- 파일 경로 자동완성 소스
  
  -- 스니펫 엔진 (자동완성 필수 짝꿍)
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },

  {
  	"vyfor/cord.nvim",
  	build = "./build",
  	event = "VeryLazy",
  	config = function()
	  require("cord").setup({})
  	end
  },
  { 'wakatime/vim-wakatime', lazy = false},
  -- lazy.nvim 플러그인 리스트에 추가할 코드
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8', -- (또는 최신 버전을 쓰셔도 됩니다)
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup({
        defaults = {
	  initial_mode = "normal",
          -- Telescope 창 안에서 쓸 수 있는 단축키 설정 (선택사항)
          mappings = {
            i = {
              -- 입력 모드일 때 Ctrl+t 누르면 새 탭으로 열기
              ["<C-t>"] = require('telescope.actions').select_tab,
            },
            n = {
              -- 일반 모드일 때 Ctrl+t 누르면 새 탭으로 열기
              ["<C-t>"] = require('telescope.actions').select_tab,
            },
          },
        },
      })
    end
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {},
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  },
  { "sindrets/diffview.nvim", dependencies = "nvim-tree/nvim-web-devicons" },
  { 'aklt/plantuml-syntax', ft = "plantuml" },
  {
    "weirongxu/plantuml-previewer.vim",
    ft = { "plantuml", "markdown" },
    dependencies = { "tyru/open-browser.vim" },
  },
  { import = "plugins" },
  {
    "nvzone/typr",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = { "Typr", "TyprStats" },
  },
  {
  "kndndrj/nvim-dbee",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  build = function()
    -- Install tries to automatically detect the install method.
    -- if it fails, try calling it with one of these parameters:
    --    "curl", "wget", "bitsadmin", "go"
    require("dbee").install()
  end,
  config = function()
    require("dbee").setup(--[[optional config]])
  end,
  },
  {
  'andymass/vim-matchup',
  init = function()
    -- modify your configuration vars here
    vim.g.matchup_treesitter_stopline = 500

    -- or call the setup function provided as a helper. It defines the
    -- configuration vars for you
    require('match-up').setup({
      treesitter = {
        stopline = 500
      }
    })
  end,
  -- or use the `opts` mechanism built into `lazy.nvim`. It calls
  -- `require('match-up').setup` under the hood
  ---@type matchup.Config
  opts = {
    treesitter = {
      stopline = 500,
    }
  }
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    ---@module "ibl"
    ---@type ibl.config
    opts = {},
  }
})

-- 3. Mason 및 LSP 기본 설정
require("mason").setup()
require("mason-lspconfig").setup({
  -- 본인이 자주 쓰는 언어의 LSP 서버를 여기에 적어두면 자동 설치됩니다.
  -- 예: pyright (파이썬), tsserver (타입스크립트), clangd (C/C++)
  ensure_installed = { "clangd", "neocmake" } 
})

-- LSP가 켜지면 실행될 자동완성 연결 설정
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local lspconfig = require('lspconfig')
-- Mason에서 설치한 LSP를 활성화하는 예시 (Lua용)
vim.lsp.config('*', {capabilities = capabilities})

vim.lsp.config('clangd', {
  capabilities = capabilities,
  cmd = {
    "clangd",
    "--clang-tidy",
    "--background-index",
    "--all-scopes-completion", 
    "--completion-style=detailed",
    "--header-insertion=never",
    "--experimental-modules-support"
  }
})

-- lspconfig 설정 파일에 추가
vim.lsp.config('neocmake', {
  root_markers = {"CMakeLists.txt", ".git", "build"},
  workspace_required = false,
})

vim.lsp.enable({ 'lua_ls', 'clangd', 'neocmake' })

-- 4. 자동완성(cmp) 세부 키매핑 설정
local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered({
      -- 💡 정상 적용된 Pmenu와 PmenuSel을 cmp 창의 기본 하이라이트로 매핑합니다.
      winhighlight = "Normal:Pmenu,CursorLine:PmenuSel,Search:None",
    }),
    documentation = cmp.config.window.bordered({
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,Search:None",
    }),
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(), -- 강제 자동완성 팝업
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- 엔터로 선택
    ['<Tab>'] = cmp.mapping(function(fallback)         -- Tab으로 다음 항목
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer' },
    { name = 'path' },
  })
})

-- lsp 호버링시 정의띄워주기
-- 커서 대기 시간 설정 (밀리초 단위, 너무 낮으면 타자 칠 때 끊김)
vim.o.updatetime = 300

-- lsp 정의, 선언, 참조 이동 단축키
-- ==========================================
-- 1. 현재 창에서 이동 (스택 활용)
-- ==========================================
vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, { desc = 'LSP: Go to Definition' })
vim.keymap.set('n', '<leader>gD', vim.lsp.buf.declaration, { desc = 'LSP: Go to Declaration' })
vim.keymap.set('n', '<leader>gr', vim.lsp.buf.references, { desc = 'LSP: Go to References' })

-- ==========================================
-- 2. 창 분할(Split)로 보기
-- ==========================================
-- 세로 분할 (Vertical Split)
vim.keymap.set('n', '<leader>gvd', '<cmd>vsp | lua vim.lsp.buf.definition()<CR>', { desc = 'Definition in Vsplit' })
vim.keymap.set('n', '<leader>gvD', '<cmd>vsp | lua vim.lsp.buf.declaration()<CR>', { desc = 'Declaration in Vsplit' })
vim.keymap.set('n', '<leader>gvr', '<cmd>vsp | lua vim.lsp.buf.references()<CR>', { desc = 'References in Vsplit' })

-- 가로 분할 (Horizontal Split)
vim.keymap.set('n', '<leader>gsd', '<cmd>sp | lua vim.lsp.buf.definition()<CR>', { desc = 'Definition in Split' })
vim.keymap.set('n', '<leader>gsD', '<cmd>sp | lua vim.lsp.buf.declaration()<CR>', { desc = 'Declaration in Split' })
vim.keymap.set('n', '<leader>gsr', '<cmd>sp | lua vim.lsp.buf.references()<CR>', { desc = 'References in Split' })

-- ==========================================
-- 3. 새 탭(Tab)으로 보기
-- ==========================================
vim.keymap.set('n', '<leader>gtd', '<cmd>tab split | lua vim.lsp.buf.definition()<CR>', { desc = 'Definition in Tab' })
vim.keymap.set('n', '<leader>gtD', '<cmd>tab split | lua vim.lsp.buf.declaration()<CR>', { desc = 'Declaration in Tab' })
vim.keymap.set('n', '<leader>gtr', '<cmd>tab split | lua vim.lsp.buf.references()<CR>', { desc = 'References in Tab' })

-- 💡 [스택 내역 확인 및 제어 단축키]
-- Telescope UI로 거쳐온 기록(스택)을 예쁘게 보면서 점프 (강추)
vim.keymap.set('n', '<leader>jl', require('telescope.builtin').jumplist, { desc = 'Stack: Show Jump List (Telescope)' })
-- 순정 Neovim 텍스트 리스트로 스택 내역 출력하기
vim.keymap.set('n', '<leader>sl', '<cmd>jumps<CR>', { desc = 'Stack: Show Raw Jump List' })
-- 너무 많이 쌓인 스택 내역을 깨끗하게 청소하기 (Reset)
vim.keymap.set('n', '<leader>sc', '<cmd>clearjumps<CR>', { desc = 'Stack: Clear Jump List' })

-- 💡 [복귀 단축키 (Neovim 내장)]
-- Ctrl + o : 이전 스택 위치로 되돌아가기 (뒤로 가기)
-- Ctrl + i : 다음 스택 위치로 전진하기 (앞으로 가기)


-- ==============================================================================
-- Catppuccin 테마용 하이라이트 오버라이드 (완성형)
-- ==============================================================================
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "catppuccin*",
  callback = function()
    -- 1. 기존에 설정한 호버창/에러창 색상
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#181825" })                 -- mantle 색상
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#89b4fa", bg = "#181825" }) -- blue + mantle

    -- 2. 자동완성 팝업창 글자색 선명하게 만들기 💡 (여기가 추가된 핵심!)
    vim.api.nvim_set_hl(0, "Pmenu", { bg = "#313244", fg = "#cdd6f4" })
    -- 팝업창 기본 글자색을 밝은 회색/흰색 톤으로 강제 지정
    vim.api.nvim_set_hl(0, "CmpItemAbbr", { fg = "#cdd6f4" }) 
    -- 검색어와 일치하는 매칭 글자색을 화사한 블루 계열로 하이라이트
    vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { fg = "#89b4fa", bold = true }) 
    -- 현재 선택된 항목의 배경색과 글자색 지정
    vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#45475a", fg = "#ffffff" })

    -- 3. 분할 창 구분선 흰색으로 변경
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#ffffff" })
    vim.api.nvim_set_hl(0, "VertSplit", { fg = "#ffffff" })
  end,
})

-- 기존 테마 적용 명령어
vim.cmd.colorscheme "catppuccin"

-- 2. 설정을 먹인 후 테마를 최종 적용
vim.cmd.colorscheme "catppuccin"


-- ==============================================================================
-- Telescope 표준 필수 단축키 설정
-- ==============================================================================
local builtin = require('telescope.builtin')

-- 1. 파일 탐색 관련 (Find)
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope: 프로젝트 내 파일 찾기' })
vim.keymap.set('n', '<leader>fr', builtin.oldfiles,   { desc = 'Telescope: 최근에 열었던 파일 목록' })
vim.keymap.set('n', '<leader>fb', builtin.buffers,    { desc = 'Telescope: 현재 열려있는 버퍼(창) 목록' })

-- 2. 텍스트 검색 관련 (Search) - 아까 설치한 ripgrep(rg) 필요!
vim.keymap.set('n', '<leader>fg', builtin.live_grep,   { desc = 'Telescope: 프로젝트 전체에서 텍스트 검색' })
vim.keymap.set('n', '<leader>fc', builtin.current_buffer_fuzzy_find, { desc = 'Telescope: 현재 파일 내에서 글자 검색' })

-- 3. Neovim 정보 및 도움말 관련 (Help)
vim.keymap.set('n', '<leader>fh', builtin.help_tags,   { desc = 'Telescope: Neovim 도움말(Help) 검색' })
vim.keymap.set('n', '<leader>fk', builtin.keymaps,     { desc = 'Telescope: 현재 등록된 전체 단축키 목록 보기' })
-- LSP 에러 자동 수정(Code Action) 단축키 설정
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'LSP: Code Action (Auto Fix)' })


-- 대충 Neotree키기
vim.keymap.set('n', '<leader>nt', function() vim.cmd('Neotree') end, { desc = '대충 Neotree키기' })

require('cord').setup {
  display = {
    theme = 'catppuccin',
    flavor = 'dark',
    view = 'full',
    swap_fields = false,
    swap_icons = false,
  },
}
