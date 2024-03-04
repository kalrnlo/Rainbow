import { defineConfig } from 'vitepress'

function sidebar() {
	return [
		{ text: 'Quack', link: '/bin' },
		{ text: 'Convert', link: '/clock' },
		{ text: 'Contrast', link: '/collection' },
		{ text: 'Distance', link: '/fetch' },
		{ text: 'Dither', link: '/future' },
		{ text: 'ImageData', link: '/guard' },
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
			{ icon: 'github', link: 'https://github.com/red-blox/util' },
			{ icon: 'discord', link: 'https://discord.gg/mchCdAFPWU' },
		],

		nav: [
			{ text: 'Installing', link: '/installing' },
		],

		sidebar: sidebar(),
	}
})
