import {migrate,pool} from '../lib/db';
migrate().then(()=>{console.log('Rayeq schema ready');return pool.end()}).catch(()=>{console.error('Database migration failed. Check the private connection configuration.');process.exit(1)});
