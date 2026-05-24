import { updateUserId } from "./seeds/update-user-id";
import { seedUserOptions } from "./seeds/user-option.seed";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function seedGlobalOptions() {
	await prisma.globalOptions.upsert({
		where: { id: 1 },
		update: {},
		create: {
			id: 1,
			enableRegistration: true,
			firstUserRegistration: true,
			siteName: "ZTNET",
		},
	});
}

async function main() {
	await seedGlobalOptions();
	await seedUserOptions();
	await updateUserId();
}

main()
	.catch((e) => {
		console.error(e);
		process.exit(1);
	})
	.finally(async () => {
		await prisma.$disconnect();
	});
