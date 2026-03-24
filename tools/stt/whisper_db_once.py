import argparse
import os

# Prevent OpenBLAS/Fortran runtime from trapping console-close events
# when launched as a subprocess without an attached console window.
os.environ.setdefault("OPENBLAS_MAIN_FREE", "1")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=3.0)
    parser.add_argument("--model", type=str, default="tiny")
    parser.add_argument("--language", type=str, default="en")
    args = parser.parse_args()

    try:
        import numpy as np
        import sounddevice as sd
        from faster_whisper import WhisperModel
    except Exception:
        print("")
        return 0

    seconds = max(1.0, min(10.0, args.seconds))
    samplerate = 16000

    try:
        audio = sd.rec(int(seconds * samplerate), samplerate=samplerate, channels=1, dtype="float32")
        sd.wait()
        pcm = np.squeeze(audio)

        model = WhisperModel(args.model, device="cpu", compute_type="int8")
        segments, _ = model.transcribe(
            pcm,
            language=args.language,
            vad_filter=True,
            beam_size=1,
            best_of=1,
            temperature=0.0,
        )

        text = " ".join(seg.text.strip() for seg in segments if seg.text).strip()
        print(text)
        return 0
    except Exception:
        print("")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
