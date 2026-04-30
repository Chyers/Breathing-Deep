import express from "express";
import cors from "cors";

const app = express();

app.use(cors());
app.use(express.json());

app.post("/dialogue", (req, res) => {
  const gameState = req.body;

  // 🎭 Personality system
  const personalities = {
    skeleton: "dry, creepy, undead humor",
    boss: "arrogant, powerful, dramatic"
  };

  const personality =
    personalities[gameState.enemy_type] || "dark creature";

  let text = "The dungeon is silent...";

  // 💀 Enemy dialogue
  if (gameState.enemy_type === "skeleton") {
    const lines = [
      "Your bones will rattle like mine!",
      "Join the eternal grave...",
      "I sense your fear...",
      "You cannot escape death!",
      "Rattle... rattle..."
    ];

    text = lines[Math.floor(Math.random() * lines.length)];
  }

  // 🧠 Player state dialogue
  else if (gameState.health < 30) {
    text = "You are fading fast...";
  } else if (gameState.enemy_count > 2) {
    text = "They surround you.";
  } else if (gameState.enemy_count === 0) {
    text = "A moment of peace.";
  }

  res.json({
    text,
    sender_id: gameState.sender_id
  });
});

app.listen(3000, () => {
  console.log("Server running on http://localhost:3000");
});