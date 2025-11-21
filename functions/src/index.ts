import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { DocumentSnapshot } from 'firebase-admin/firestore';

// Инициализация Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Радиус поиска мастера в километрах (5 км)
const SEARCH_RADIUS_KM = 5;

// Определения типов для координат
interface Location {
    latitude: number;
    longitude: number;
}

// Определения типов для мастера
interface MasterMatch {
    id: string;
    name: string;
    distance: number;
}

/**
 * Вычисляет расстояние между двумя координатами (в км) с использованием формулы Гаверсина.
 * @param loc1 - Координаты точки 1
 * @param loc2 - Координаты точки 2
 * @returns Расстояние в километрах
 */
function getDistance(loc1: Location, loc2: Location): number {
    const R = 6371; // Радиус Земли в км
    const dLat = (loc2.latitude - loc1.latitude) * Math.PI / 180;
    const dLon = (loc2.longitude - loc1.longitude) * Math.PI / 180;
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(loc1.latitude * Math.PI / 180) * Math.cos(loc2.latitude * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const d = R * c;
    return d;
}

/**
 * Триггер Cloud Function: срабатывает при создании нового заказа со статусом 'pending'.
 */
export const matchNearestMaster = functions.firestore.onDocumentCreated('orders/{orderId}', async (event) => {

    // Получаем DocumentSnapshot и ID заказа
    const snap = event.data as DocumentSnapshot;
    const orderId = event.params.orderId;

    if (!snap) {
        console.log("Нет данных снимка.");
        return null;
    }

    const orderData = snap.data();
    // Используем опциональную цепочку и явное приведение типов
    const orderCategory = orderData?.category as string;
    const clientLocation = orderData?.client_location as Location;

    if (orderData?.status !== 'pending' || !clientLocation) {
        console.log("Заказ не в статусе pending или нет геолокации клиента. Пропускаем.");
        return null;
    }

    console.log(`Начинаем поиск мастера для заказа ${orderId} (Категория: ${orderCategory})`);

    let nearestMaster: MasterMatch | null = null;
    let minDistance = Infinity;

    try {
        // 1. Поиск потенциальных мастеров
        const mastersSnapshot = await db.collection('users')
            // Используем array-contains для массива 'specialization'
            .where('specialization', 'array-contains', orderCategory)
            .where('is_available', '==', true)
            .get();

        if (mastersSnapshot.empty) {
            console.log(`Мастера по категории ${orderCategory} не найдены.`);
            return snap.ref.update({
                status: 'no_master_found',
                updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // 2. Итерация по мастерам для поиска ближайшего
        mastersSnapshot.forEach(doc => {
            const master = doc.data();
            const masterId = doc.id;

            // Проверяем, что у мастера есть имя и координаты
            if (master.last_location && master.name) {
                const masterLocation = master.last_location as Location;
                const distance = getDistance(clientLocation, masterLocation);

                // Проверяем, находится ли мастер в пределах радиуса и ближе предыдущего
                if (distance <= SEARCH_RADIUS_KM && distance < minDistance) {
                    minDistance = distance;
                    nearestMaster = {
                        id: masterId,
                        name: master.name as string,
                        distance: distance,
                    };
                }
            }
        });

        // 3. Назначение или отказ
        if (nearestMaster) {
            // Явное приведение типа для обхода строгих проверок TypeScript
            const masterToAssign = nearestMaster as MasterMatch;

            const distanceKm = masterToAssign.distance.toFixed(1);
            console.log(`Найден ближайший мастер: ${masterToAssign.name} (${distanceKm} км)`);

            // Назначаем мастера на заказ и обновляем его статус
            await snap.ref.update({
                status: 'assigned',
                master_id: masterToAssign.id,
                master_name: masterToAssign.name,
                distance_to_master_km: distanceKm,
                updated_at: admin.firestore.FieldValue.serverTimestamp()
            });

        } else {
            console.log(`Мастера в радиусе ${SEARCH_RADIUS_KM} км не найдены.`);
            await snap.ref.update({
                status: 'no_master_found',
                updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
        }

    } catch (error: any) {
        console.error("Ошибка при сопоставлении мастера:", error);

        return snap.ref.update({
            status: 'error_matching',
            error_message: error.message,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
    }

    return null;
});