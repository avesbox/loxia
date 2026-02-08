import { defineConfig } from 'vitepress'
import Tailwind from '@tailwindcss/vite'
import { serinusNocturneTheme, serinusParchmentTheme } from './theme/serinus-parchment'
import llmstxt from 'vitepress-plugin-llms'

// https://vitepress.dev/reference/site-config

const description = "Loxia is a lightweight ORM for Dart, designed to provide a simple and efficient way to interact with databases. It supports SQLite and PostgreSQL, offering type-safe queries and an elegant API for developers."
export default defineConfig({
  title: "Loxia",
  titleTemplate: ':title - Loxia | The Lightweight Dart ORM',
  description,
  head: [
    ['link', { rel: "icon", type: "image/png", href: "/loxia-logo.png" }],
    ['link', { rel: "apple-touch-icon", href: "/loxia-logo.png" }],
    [
        'meta',
        {
            name: 'viewport',
            content: 'width=device-width,initial-scale=1,user-scalable=no'
        }
    ],
    [
        'meta',
        {
            property: 'og:title',
            content: 'Loxia'
        }
    ],
    [
        'meta',
        {
            property: 'og:description',
            content: description
        }
    ],
    [
        'meta',
        {
            property: 'keywords',
            content: 'loxia, dart loxia, loxia orm, loxia dart orm, loxia database, loxia database orm, dart database orm, dart orm, flutter orm, flutter database orm'
        }
    ],
  ],
  markdown: {
    image: {
      lazyLoading: true
    },
    theme: {
      light: {
        ...serinusParchmentTheme,
        type: "light"
      },
      dark: {
        ...serinusNocturneTheme,
        type: "dark"
      }
    },
  },
  sitemap: {
    hostname: 'https://loxia.avesbox.com',
  },
  lastUpdated: true,
  appearance: {
    initialValue: undefined
  },
  ignoreDeadLinks: true,
  themeConfig: {
    // footer: {
    //   copyright: 'Copyright © 2025 Francesco Vallone',
    //   message: 'Built with 💙 and Dart 🎯 | One of the 🐤 of <a href="https://github.com/avesbox">Avesbox</a>',
    // },
    // https://vitepress.dev/reference/default-theme-config
    logo: '/loxia-logo.png',
    search: {
      provider: 'local',
      options: {
        translations: {
          button: {
            buttonText: 'Search docs...',
          }
        }
      }
    },
    siteTitle: false,
    nav: [
      {
        text: 'Documentation',
        link: '/introduction'
      },
    ],
    sidebar: [
      {
        items: [
          {
            text: 'Introduction',
            link: '/introduction'
          },
          {
            text: 'Overview',
            base: '/',
            items: [
              { text: 'Getting Started', link: 'getting_started' },
              { text: 'Define your Entities', link: 'define_your_entities' },
              { text: 'Repositories', link: 'repositories' },
              { text: 'Relationships', link: 'relationships' },
              { text: 'Lifecycle Hooks', link: 'lifecycle_hooks' },
              { text: 'Migrations', link: 'migrations' },
            ]
          },
        ]
      },
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/avesbox/loxia' },
      { icon: 'twitter', link: 'https://twitter.com/avesboxx'},
      { icon: 'discord', link: 'https://discord.gg/zydgnJ3ksJ' }
    ],
  },
  vite: {
    plugins: [
      Tailwind(),
      process.env.NODE_ENV ? llmstxt({
        ignoreFiles: [
          'blog/*',
          'index.md',
          'public/*',
          'plugins/*',
          'next/*'
        ],
        domain: 'https://serinus.app'
      }) : undefined
    ]
  }
})