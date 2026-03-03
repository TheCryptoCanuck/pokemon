import { GameProvider } from '../context/GameContext';
import AppShell from '../components/layout/AppShell';

export default function Home() {
  return (
    <GameProvider>
      <AppShell />
    </GameProvider>
  );
}
