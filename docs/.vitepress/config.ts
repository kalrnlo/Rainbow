import { defineConfig } from 'vitepress'

function sidebar() {
	return [
		{ text: 'Quack', link: '/Quack' },
		{ text: 'Convert', link: '/Convert' },
		{ text: 'Contrast', link: '/Contrast' },
		{ text: 'Distance', link: '/Distance' },
		{ text: 'Dither', link: '/Dither' },
		{ text: 'ImageData', link: '/ImageData' },
		{ text: 'Palette', link: '/Palette' },
	]
}

export default defineConfig({
	title: 'Rainbow',
	description: 'A collection of small utilities for Roblox.',
	lang: 'en-US',
	head: [
		//['link', { rel: 'icon', href: '/favicon.png' }],
	],

	themeConfig: {
		//logo: '/logo.png',
		//siteTitle: false,
		outline: 'deep',

		socialLinks: [
			{ icon: 'github', link: 'https://github.com/kalrnlo/Rainbow' },
			{ icon: 'discord', link: 'https://discord.gg/mchCdAFPWU' },
		],

		nav: [
			{ text: 'Installing', link: '/installing' },
		],

		sidebar: sidebar(),
	}
})
