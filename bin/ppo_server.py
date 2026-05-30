#!/usr/bin/env python3
"""
PPO policy server for FightingAI.

Communicates with the Ruby training layer via stdin/stdout using
newline-delimited JSON. Stays alive for the entire training session.

Commands
--------
forward  { "cmd": "forward", "obs": [float, ...] }
         → { "action_index": int, "log_prob": float, "value": float }

update   { "cmd": "update", "transitions": [{obs, action, reward, log_prob, value, done}, ...] }
         → { "policy_loss": float, "value_loss": float, "entropy": float, "total_loss": float }

save     { "cmd": "save", "path": "/path/to/dir" }
         → { "ok": true }

load     { "cmd": "load", "path": "/path/to/dir" }
         → { "ok": true }
"""

import sys
import os
import json
import argparse
import numpy as np

try:
    import torch
    import torch.nn as nn
    import torch.optim as optim
    from torch.distributions import Categorical
except ImportError:
    sys.stdout.write(json.dumps({"error": "torch not installed. Run: pip install torch"}) + "\n")
    sys.stdout.flush()
    sys.exit(1)

# ── Hyperparameters ──────────────────────────────────────────────────────────
LEARNING_RATE   = 3e-4
CLIP_EPS        = 0.2
VALUE_COEF      = 0.5
ENTROPY_COEF    = 0.05
GAE_LAMBDA      = 0.95
GAMMA           = 0.99
PPO_EPOCHS      = 4
MINI_BATCH_SIZE = 64


# ── Network ──────────────────────────────────────────────────────────────────
class ActorCritic(nn.Module):
    def __init__(self, obs_dim: int, act_dim: int, hidden_dim: int = 64):
        super().__init__()
        self.shared = nn.Sequential(
            nn.Linear(obs_dim, hidden_dim), nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim), nn.ReLU(),
        )
        self.actor  = nn.Linear(hidden_dim, act_dim)
        self.critic = nn.Linear(hidden_dim, 1)

    def forward(self, x):
        h      = self.shared(x)
        logits = self.actor(h)
        value  = self.critic(h).squeeze(-1)
        return logits, value


# ── GAE ──────────────────────────────────────────────────────────────────────
def compute_gae(rewards, values, dones, last_value: float = 0.0):
    n          = len(rewards)
    advantages = np.zeros(n, dtype=np.float32)
    gae        = 0.0
    next_val   = last_value

    for t in reversed(range(n)):
        mask         = 1.0 - float(dones[t])
        delta        = float(rewards[t]) + GAMMA * next_val * mask - float(values[t])
        gae          = delta + GAMMA * GAE_LAMBDA * mask * gae
        advantages[t] = gae
        next_val     = float(values[t])

    returns = advantages + np.array(values, dtype=np.float32)
    return advantages, returns


# ── Server ───────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="FightingAI PPO policy server")
    parser.add_argument("--obs-dim", type=int, required=True, help="Observation vector size")
    parser.add_argument("--act-dim", type=int, required=True, help="Number of discrete actions")
    parser.add_argument("--hidden",  type=int, default=64,    help="Hidden layer size")
    args = parser.parse_args()

    model     = ActorCritic(args.obs_dim, args.act_dim, args.hidden)
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

    # Signal to Ruby that the server is ready.
    sys.stdout.write("ready\n")
    sys.stdout.flush()

    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue

        try:
            req = json.loads(line)
        except json.JSONDecodeError as exc:
            _respond({"error": f"JSON parse error: {exc}"})
            continue

        cmd = req.get("cmd")

        # ── forward ──────────────────────────────────────────────────────────
        if cmd == "forward":
            obs    = torch.tensor(req["obs"], dtype=torch.float32).unsqueeze(0)
            with torch.no_grad():
                logits, value = model(obs)
            dist = Categorical(logits=logits)
            if "action_index" in req:
                action = torch.tensor(req["action_index"])
            else:
                action = dist.sample()
            log_prob = dist.log_prob(action)
            _respond({
                "action_index": int(action.item()),
                "log_prob":     float(log_prob.item()),
                "value":        float(value.item()),
            })

        # ── update ───────────────────────────────────────────────────────────
        elif cmd == "update":
            trs      = req["transitions"]
            obs_arr  = np.array([t["obs"]      for t in trs], dtype=np.float32)
            act_arr  = np.array([t["action"]   for t in trs], dtype=np.int64)
            rew_arr  = np.array([t["reward"]   for t in trs], dtype=np.float32)
            lp_arr   = np.array([t["log_prob"] for t in trs], dtype=np.float32)
            val_arr  = np.array([t["value"]    for t in trs], dtype=np.float32)
            done_arr = np.array([t["done"]     for t in trs], dtype=np.float32)

            advantages, returns = compute_gae(rew_arr, val_arr, done_arr)
            advantages = (advantages - advantages.mean()) / (advantages.std() + 1e-8)

            obs_t    = torch.tensor(obs_arr)
            act_t    = torch.tensor(act_arr)
            ret_t    = torch.tensor(returns)
            adv_t    = torch.tensor(advantages)
            old_lp_t = torch.tensor(lp_arr)

            n            = len(trs)
            total_p_loss = 0.0
            total_v_loss = 0.0
            total_ent    = 0.0
            n_batches    = 0

            for _ in range(PPO_EPOCHS):
                indices = np.random.permutation(n)
                for start in range(0, n, MINI_BATCH_SIZE):
                    idx = torch.tensor(indices[start : start + MINI_BATCH_SIZE])

                    logits, values = model(obs_t[idx])
                    dist   = Categorical(logits=logits)
                    lp     = dist.log_prob(act_t[idx])
                    ent    = dist.entropy().mean()

                    ratio      = torch.exp(lp - old_lp_t[idx])
                    adv_mb     = adv_t[idx]
                    clip_ratio = torch.clamp(ratio, 1.0 - CLIP_EPS, 1.0 + CLIP_EPS)
                    p_loss     = -torch.min(ratio * adv_mb, clip_ratio * adv_mb).mean()
                    v_loss     = VALUE_COEF * (values - ret_t[idx]).pow(2).mean()
                    loss       = p_loss + v_loss - ENTROPY_COEF * ent

                    optimizer.zero_grad()
                    loss.backward()
                    nn.utils.clip_grad_norm_(model.parameters(), 0.5)
                    optimizer.step()

                    total_p_loss += float(p_loss.item())
                    total_v_loss += float(v_loss.item())
                    total_ent    += float(ent.item())
                    n_batches    += 1

            nb = max(n_batches, 1)
            _respond({
                "policy_loss": total_p_loss / nb,
                "value_loss":  total_v_loss / nb,
                "entropy":     total_ent    / nb,
                "total_loss":  (total_p_loss + total_v_loss) / nb,
            })

        # ── save ─────────────────────────────────────────────────────────────
        elif cmd == "save":
            path = req["path"]
            os.makedirs(path, exist_ok=True)
            torch.save(
                {"model": model.state_dict(), "optimizer": optimizer.state_dict()},
                os.path.join(path, "policy.pt"),
            )
            _respond({"ok": True})

        # ── load ─────────────────────────────────────────────────────────────
        elif cmd == "load":
            pt_path = os.path.join(req["path"], "policy.pt")
            if os.path.exists(pt_path):
                ckpt = torch.load(pt_path, weights_only=True)
                model.load_state_dict(ckpt["model"])
                optimizer.load_state_dict(ckpt["optimizer"])
                _respond({"ok": True})
            else:
                _respond({"ok": False, "error": f"not found: {pt_path}"})

        else:
            _respond({"error": f"unknown cmd: {cmd!r}"})


def _respond(payload: dict):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


if __name__ == "__main__":
    main()
